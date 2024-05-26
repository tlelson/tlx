#!/usr/bin/env bash

cp-list() {
    aws --output json codepipeline list-pipelines | jq -r '.pipelines[].name'
}
export -f cp-list
cp-start() {
    aws codepipeline start-pipeline-execution --name "$1"
}
export -f cp-start

# TODO:
#   - Allow no arguments for all pipelines and their status (change to cp-status)
#   - Show Source commits of the execution at each stage
cp-state() {
    local help_text="Usage: ${FUNCNAME[0]} [options] [positional Args] [Optional Args]
    Summarised current state of the specified pipeline.

    Options:
    -g/--guess      Guess the pipeline name from non-exact 'pipeline_name'
    -f/--full       Full state. Not summarised.
    --help          Display this help message

    Positional Arguments
    pipeline_name   string matching one pipeline name. e.g 'meta'

    Optional Arguments
    stage_name      StageName to restrict output to. e.g 'Dev'
    "

    # TODO: For each executionId (at each stage, get the Source version of each)
    # This is probably getting too complex for jq now.

    local full=0
    local guess_name=0
    local pipeline_name=""
    local stage_name=""

    # Check if no arguments are provided
    if [[ $# -eq 0 ]]; then
        echo "$help_text"
        return 1
    fi

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -f | --full)
            full=1
            shift
            ;;
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
            if [[ -z "$pipeline_name" ]]; then
                pipeline_name="$1"
            elif [[ -z "$stage_name" ]]; then
                stage_name="$1"
            else
                echo "Unexpected argument: $1"
                echo "$help_text"
                return 1
            fi
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

    state=$(aws --output json codepipeline get-pipeline-state --name "$pipeline_name")

    if ((full == 1)); then
        echo "${state}" | jq
        return 0
    fi

    result=$(echo "${state}" | jq '
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
        ')
    # --arg stage_name "$stage_name"
    if [ -z "$stage_name" ]; then
        echo "$result" | jq
    else
        echo "$result" | jq "{pipelineName, updated,
            stage: .stages[]| select(.stageName==\"$stage_name\")
        }"
    fi
}
export -f cp-state

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
    pipeline_name_filter    grep regex to filter pipelines

    Options:
    --help                  Display this help message"

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
        echo "PIPELINE STATUS LASTRUN"
        aws --output json codepipeline list-pipelines | jq '.pipelines[].name' |
            grep "${filter_pattern}" | xargs -P20 -n1 -I {} sh -c 'aws --output json \
                    codepipeline list-pipeline-executions \
                    --pipeline-name "$1" --max-items 1 | jq -r --arg p "$1" \
                    '\''.pipelineExecutionSummaries[0] | [$p, .status, .startTime] |
                    .[2] |= sub(":[0-9]{2}\\.[0-9]{6}"; "")  | @tsv'\'' ' _ {}

    } | column -t

}
export -f cp-status

cp-definition() {
    local help_text="Usage: ${FUNCNAME[0]} [Arguments] [Optional Arguments] [options]

    Arguments:
    pipeline_name

    Optional Arguments:
    version         Default: current version. See execution list for version tags.

    Options:
    --help          Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 1
    fi

    if [ -z "$1" ]; then
        echo "$help_text"
        return 1
    fi
    cmd="aws --output json codepipeline get-pipeline --name $1"

    if [ -n "$2" ]; then
        cmd="$cmd --pipeline-version $2"
    fi

    eval "$cmd" | jq '{pipeline}'

}
export -f cp-definition

cp-update() {
    local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]

    Arguments:
    file-path   Path to a yaml file that describes the pipeline to be updated. e.g /tmp/pipeline.yaml

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
