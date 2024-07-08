#!/usr/bin/env bash

alias codepipeline='echo "CodePipeline tools are prefixed with \`cp-\`"'

cp-list() {
    aws --output json codepipeline list-pipelines | jq -r '.pipelines[].name'
}
export -f cp-list
cp-start() {
    aws codepipeline start-pipeline-execution --name "$1" | jq -c
}
export -f cp-start

# TODO:
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

    Examples:
    ${FUNCNAME[0]} \$p| jtbl
    ${FUNCNAME[0]} \$p | jq -c '.stages[] | {
        stageName, status, pipelineExecutionId, time
    }' | jtbl

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
            .stageStates[] |
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
                    transitionEnabled: .inboundTransitionState.enabled,
                    time: [ .actionStates[].latestExecution.lastStatusChange | select(. != null ) ] | sort | .[-1] ,
                }
            else
                { stageName, status: .latestExecution.status,
                    pipelineExecutionId: .latestExecution.pipelineExecutionId,
                    transitionEnabled: .inboundTransitionState.enabled,
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
    pipeline=$(cp-state "${pipeline_name}")

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

    if [[ -z "$action" ]]; then
        echo "Stage has no 'InProgress' actions. Rerun the pipeline first."
        return 1
    fi

    action_name=$(echo "$action" | jq -r '.actionName')
    token=$(echo "$action" | jq -r '.token')

    if [[ -z "$token" ]]; then
        echo "Could not get a 'token' for this stage."
        return 1
    fi

    aws --output json codepipeline put-approval-result \
        --pipeline-name "${pipeline_name}" \
        --stage-name "${stage_to_approve}" \
        --action-name "${action_name}" \
        --result 'summary="",status=Approved' \
        --token "${token}"

}
export -f cp-approve

cp-retry() {
    if [ "$#" -ne 2 ]; then
        echo "provide a pipeline name as the first argument, the stage as a second argument."
        echo "e.g ${FUNCNAME[0]} 'meta' 'Approval_To_Staging' "
        return 1
    fi
    pipeline_name="$1"
    stage="$2"

    pipeline=$(cp-state "${pipeline_name}")
    execution_id=$(echo "$pipeline" | jq -r --arg stage "$stage" '.stages[] | select(.stageName==$stage) | .pipelineExecutionId')

    if [[ -z "$execution_id" ]]; then
        echo "Could not get a 'execution_id' for this stage."
        return 1
    fi

    aws codepipeline retry-stage-execution \
        --pipeline-name "${pipeline_name}" \
        --stage-name "${stage}" \
        --pipeline-execution-id "${execution_id}" \
        --retry-mode FAILED_ACTIONS | jq -c

}
export -f cp-retry

cp-status() {
    # Define the help text
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    Providing a filter pattern as an optional argument is more efficient than grepping the output stream because it limits the amount data that is requested from the AWS API's.

    Returns jsonlines.

    Optional Arguments:
    pipeline_name_filter    Glob pattern to reduce output.

    Options:
    --help                  Display this help message

    Examples:
    ${FUNCNAME[0]} 'deploy' | jtbl
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    filter_pattern='"*"'

    if [ "$#" -ne 0 ]; then
        filter_pattern="$*"
    fi

    cmd='
        aws --output json codepipeline list-pipeline-executions \
            --pipeline-name "$1" --max-items 1 | jq -c --arg p "$1" \
            '"'"'
            if (.pipelineExecutionSummaries | length) == 0 then
                {Name: $p, Status: "NO_EXECUTIONS", LastRun: "N/A"}
            else
                .pipelineExecutionSummaries[0] | {
                    Name: $p, Status: .status?,
                    LastRun: .startTime | sub(":[0-9]{2}\\.[0-9]{6}";"")
                }
            end
            '"'"'
    '

    aws --output json codepipeline list-pipelines | jq '.pipelines[].name' |
        grep "${filter_pattern}" | xargs -P32 -I {} sh -c "$cmd" _ {}

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
