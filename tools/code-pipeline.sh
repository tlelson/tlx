#!/usr/bin/env bash

alias code-pipelines="aws --output json codepipeline list-pipelines | jq -r '.pipelines[].name' "
alias code-pipeline-get-state='aws --output json codepipeline get-pipeline-state --name '

code-pipeline-check() {

	# This is probably getting too complex for jq now.

	if [ -z "$1" ]; then
		echo "${FUNCNAME[0]} \$pipeline_name "
		exit 1
	fi

	aws --output json codepipeline get-pipeline-state \
		--name "$1" | jq '
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
export -f code-pipeline-check

code-pipeline-approve() {
	if [ -z "$1" ]; then
		echo "provide a pipeline name as the first argument, and optionally, the stage as a second argument.  If only one stage is approvable, it will be approved."
		echo "e.g ${FUNCNAME[0]} 'meta' "
		echo "e.g ${FUNCNAME[0]} 'meta' 'Approval_To_Staging' "
		exit 1
	fi
	pipeline_name="$1"
	# TODO: Could do this more efficiently with aws cmd
	pipeline=$(code-pipeline-check "${pipeline_name}")

	stage_to_approve=""

	if [ -z "$2" ]; then

		readarray approvable_stages < <(echo "${pipeline}" | jq -r '[.stages[] | select(.stageName|test("Approval.*")) | select(.status == "InProgress")  | .stageName] | .[]')

		if [ ${#approvable_stages[@]} -ne 1 ]; then
			echo "Approvable stages are: "
			for stage in "${approvable_stages[@]}"; do
				stage=$(echo "$stage" | tr -d '\n')
				echo "\"${stage}\""
			done
			exit 1
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
export -f code-pipeline-approve

code-pipeline-status() {
	# Define the help text
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

	Optional Arguments:
	pipeline_name_filter	grep regex to filter pipelines

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi

	filter_pattern='"*"'

	if [ "$#" -ne 0 ]; then
		filter_pattern="$*"
	fi

	{
		echo "PIPELINE STATUS TIME"
		aws --output json codepipeline list-pipelines | jq '.pipelines[].name' |
			grep "${filter_pattern}" | xargs -P20 -n1 -I {} bash -c 'code-pipeline-check {}' |
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
export -f code-pipeline-status
