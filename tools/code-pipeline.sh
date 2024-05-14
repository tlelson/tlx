#!/usr/bin/env bash

alias cp-list="aws --output json codepipeline list-pipelines | jq -r '.pipelines[].name' "
alias cp-get-state='aws --output json codepipeline get-pipeline-state --name '
alias cp-start='aws codepipeline start-pipeline-execution --name '

cp-check() {
	local help_text="Usage: ${FUNCNAME[0]} [options] [positional args]

	Options:
	-g/--guess		Guess the pipeline name from non-exact 'pipeline_name'
	--help			Display this help message

	Positional Arguments
	pipeline_name		string matching one pipeline name. e.g 'meta'
	"

	# TODO: For each executionId (at each stage, get the Source version of each)
	# This is probably getting too complex for jq now.

	local guess_name=0
	local pipeline_name=""

	# Check if no arguments are provided
	if [[ $# -eq 0 ]]; then
		echo "$help_text"
		return 1
	fi

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-g | --guess)
			guess_name=1
			shift
			;;
		--help)
			echo "$help_text"
			return 0
			;;
		-*)
			echo "Unknown option: $1"
			echo "$help_text"
			return 1
			;;
		*)
			pipeline_name="$1"
			shift
			;;
		esac
	done

	if ((guess_name == 1)); then
		names=$(cp-list | grep "$pipeline_name")
		count=$(wc -l <<<"$names")

		if ((count == 0)); then
			echo "could not find a pipeline containing pattern: $1"
			return 1
		fi

		if ((count > 1)); then
			echo "Ambiguous pipeline glob pattern: $1"
			echo "Got $count matching pipelines: "
			while IFS= read -r line; do
				echo -e "\t$line"
			done <<<"$names"
			return 1
		fi

		pipeline_name="$names"
	fi

	aws --output json codepipeline get-pipeline-state \
		--name "$pipeline_name" | jq '
		{pipelineName, updated, stages: [
			.stageStates[] | select(.latestExecution.status) |
			if ( .stageName == "Source") and (.latestExecution.status == "Succeeded")  then
				{ stageName , status: .latestExecution.status,
					sources: [
						.actionStates[] |
							if (.latestExecution != null) and ( .latestExecution.summary|startswith("{") ) then
								{
									actionName, lastStatusChange: .latestExecution.lastStatusChange,
									msg: .latestExecution.summary | fromjson |
										.CommitMessage|split("\n")[0],
								}
							else
								{
									actionName, lastStatusChange: .latestExecution.lastStatusChange,
									msg: .latestExecution.summary
								}
							end
					]
				}
			elif .latestExecution.status == "Succeeded" then
				{ stageName , status: .latestExecution.status,
					pipelineExecutionId: .latestExecution.pipelineExecutionId,
					time: [ .actionStates[].latestExecution.lastStatusChange | select(. != null ) ] | sort | .[-1] ,
				}
			else
				{ stageName, status: .latestExecution.status,
					pipelineExecutionId: .latestExecution.pipelineExecutionId,
					actions: [ .actionStates[]? | select(.latestExecution.status) |
					if .latestExecution.status == "Failed" then
						{ actionName , status: .latestExecution.status,
						summary: .latestExecution.summary,
						message: .latestExecution.errorDetails.message? ,
						time: .latestExecution.lastStatusChange? ,
						executionId: .latestExecution.actionExecutionId,
						url: .latestExecution.externalExecutionUrl,
					} | delpaths([. | to_entries | .[] | select(.value == null) | [.key]])
					elif .latestExecution.status == "InProgress" then
						{ actionName , status: .latestExecution.status,
						token: .latestExecution.token,
						}
					else
						{ actionName , status: .latestExecution.status }
					end
				] }
			end
			]
		}
	'
}
export -f cp-check

cp-approve() {
	if [ -z "$1" ]; then
		echo "provide a pipeline name as the first argument, and optionally, the stage as a second argument.  If only one stage is approvable, it will be approved."
		echo "e.g ${FUNCNAME[0]} 'meta' "
		echo "e.g ${FUNCNAME[0]} 'meta' 'Approval_To_Staging' "
		return 1
	fi
	pipeline_name="$1"
	# TODO: Could do this more efficiently with aws cmd
	pipeline=$(cp-check "${pipeline_name}")

	stage_to_approve=""

	if [ -z "$2" ]; then

		readarray approvable_stages < <(echo "${pipeline}" | jq -r '[.stages[] | select(.stageName|test("Approval.*")) | select(.status == "InProgress")  | .stageName] | .[]')

		if [ ${#approvable_stages[@]} -ne 1 ]; then
			echo "Approvable stages are: "
			for stage in "${approvable_stages[@]}"; do
				stage=$(echo "$stage" | tr -d '\n')
				echo "\"${stage}\""
			done
			return 1
		else
			stage_to_approve=$(echo "${approvable_stages[0]}" | tr -d '\n')
		fi
	else
		stage_to_approve="$2"
	fi

	echo "approving stage: ${stage_to_approve}"

	action=$(echo "${pipeline}" | jq -rc --arg stage "${stage_to_approve}" '.stages[] | select(.stageName == $stage) | .actions[] | select(.status == "InProgress") | {actionName, token}')
	action_name=$(echo "$action" | jq -r '.actionName')
	token=$(echo "$action" | jq -r '.token')

	aws --output json codepipeline put-approval-result \
		--pipeline-name "${pipeline_name}" \
		--stage-name "${stage_to_approve}" \
		--action-name "${action_name}" \
		--result 'summary="",status=Approved' \
		--token "${token}"

}
export -f cp-approve

cp-status() {
	# Define the help text
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

	Optional Arguments:
	pipeline_name_filter	grep regex to filter pipelines

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0
	fi

	filter_pattern='"*"'

	if [ "$#" -ne 0 ]; then
		filter_pattern="$*"
	fi

	{
		echo "PIPELINE STATUS TIME"
		aws --output json codepipeline list-pipelines | jq '.pipelines[].name' |
			grep "${filter_pattern}" | xargs -P20 -n1 -I {} bash -c 'cp-check {}' |
			jq -c ' {
	    	pipelineName, stages: [.stages |
	    	if all(.status == "Succeeded") then
	    		.[-1] |
	    			{status, time}
	    	elif any(.status == "Failed") then
	    		.[] | select(.status == "Failed") |
	    			{status, time: .time?}
	    	else
	    		.[] | select(.status != "Succeeded") |
	    			{status, time}
	    	end
	    ]  | .[0]
	    }' | jq -rc '[.pipelineName, .stages.status, .stages.time?[:19] ] | @tsv'
	} | column -t

}
export -f cp-status

cp-get() {
	local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]

	Arguments:
	pipeline_name

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 1
	fi

	if [ -z "$1" ]; then
		echo "$help_text"
		return 1
	fi
	pipeline_name="$1"

	aws --output json codepipeline get-pipeline --name "${pipeline_name}" |
		jq '{pipeline}' | json2yaml

}
export -f cp-get

cp-update() {
	local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]

	Arguments:
	file-path	Path to a yaml file that describes the pipeline to be updated. e.g /tmp/pipeline.yaml

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 1
	fi

	if [ -z "$1" ]; then
		echo "$help_text"
		return 1
	fi

	aws codepipeline update-pipeline --cli-input-yaml "file://$1" >/dev/null
}
export -f cp-update
