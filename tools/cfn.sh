#!/usr/bin/env bash

## Cloudformation Tools
#
# Tools prefixed by `cfn` are not stack specific.  Tools prefixed by `stack` are stack
# specific and take an argument 'stack_name'.

cfn-exports() {
    # This returns all cfn exports.  It takes an optional argument that filters
    # by glob pattern
    # E.g:
    #   cfn-exports | jtbl -n
    #   cfn-exports 'subnet'

    exports=$(aws --output json cloudformation list-exports)

    jq_exp='.Exports[]'

    if [ "$#" -ne 0 ]; then
        jq_exp+="| select(.Name|test(\".*${*}.*\"))"
    fi

    # Tabulate response
    jq_exp+='| {Stack: .ExportingStackId | sub("^[^/]+/"; "") | sub("/.*$"; ""), Name, Value}'
    echo "${exports}" | jq -c "$jq_exp"
}
export -f cfn-exports

# TODO: Speedup
cfn-resources() {
    # This returns all resources deployed by all cfn stacks.  It takes an optional argument
    # that defines the level of concurrency.
    # E.g:
    #   cfn-resources           # Uses 32 concurrent processes
    #   cfn-resources 4         # Uses  4 concurrent processes

    concurrency=32

    if [ -n "$2" ]; then
        concurrency="$2"
    fi

    ## Parrallel

    task() {
        aws --output json cloudformation list-stack-resources --stack-name "$1" |
            jq -c --arg stack_name "$1" '.StackResourceSummaries[] | {StackName: $stack_name, ResourceType, PhysicalResourceId, LogicalResourceId}'
    }

    stacks=$(aws --output json cloudformation list-stacks | jq -r '.StackSummaries[] | select(.StackStatus != "DELETE_COMPLETE") | .StackName')

    (
        for stack_name in ${stacks}; do
            ((i = i % concurrency)) # Exits with i. Can't exit on first error
            ((i++ == 0)) && wait
            #echo "${stack_name}" &
            task "${stack_name}" &
        done
    )

}
export -f cfn-resources

stack-events() {
    event_limit=10

    if [ -z "$1" ]; then
        echo "provide a stack name as the first argument"
        return 1
    fi

    if [ -n "$2" ]; then
        event_limit="$2"
    fi

    aws --output json cloudformation describe-stack-events --stack-name "$1" \
        --max-items "${event_limit}" | jq '.StackEvents | map({
        ResourceType, LogicalResourceId, ResourceStatus, Timestamp, ResourceStatusReason })'

}
export -f stack-events

stack-failed() {
    if [ -z "$1" ]; then
        echo "provide a stack name as the first argument"
        return 1
    fi
    stack_name="$1"

    stack-events "$stack_name" 50 | jq '[
        .[] | select(.ResourceStatus|test(".*FAILED")) ]'
}
export -f stack-failed

stack-params() {

    if [ -z "$1" ]; then
        echo "Output is JSON by default because the output may be used as input for deploy."
        echo "${FUNCNAME[0]} \$stack_name | jtbl"
        return 1
    fi
    stack_name="$1"

    aws --output json cloudformation describe-stacks --stack-name "$stack_name" |
        jq -r '.Stacks[0].Parameters'

}
export -f stack-params

stack-status() {

    stack_status=$(aws --output json cloudformation list-stacks |
        jq -rc '.StackSummaries[] | [ .StackName[:60], .StackStatus,
            (.LastUpdatedTime // .CreationTime)
            ] | .[2] |= sub(":[0-9]{2}\\.[0-9]{6}"; "") | @tsv ' |
        grep -v 'DELETE_COMPLETE')

    {
        echo "STACKNAME STATUS UPDATED"
        if [ "$#" -ne 0 ]; then
            echo "$stack_status" | grep --color=auto "$*"
        else
            echo "$stack_status"
        fi
    } | column -t

}
export -f stack-status

stack-template() {
    if [ -z "$1" ]; then
        echo "Returns the template used to deploy a stack"
        echo "${FUNCNAME[0]} \$stack_name"
        return 1
    fi
    stack_name="$1"

    aws --output json cloudformation get-template --stack-name "$stack_name" |
        jq -r '.TemplateBody'

}
export -f stack-template

alias stack-resources='aws cloudformation list-stack-resources --stack-name '

stack-deploy() {
    local help_text="Usage: ${FUNCNAME[0]} [Arguments] [OPTIONAL_ARGS] [options]

    Arguments:
    stack_name
    template_file

    Optional Arguments:
    parameters_file         Use 'stack-params' to produce

    Options:
    --help       Display this help message"

    # Initialize variables
    local stack_name=""
    local template_file=""
    local parameters_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help)
            echo "$help_text"
            return 0
            ;;
        *)
            if [[ -z "$stack_name" ]]; then
                stack_name="$1"
            elif [[ -z "$template_file" ]]; then
                template_file="$1"
            elif [[ -z "$parameters_file" ]]; then
                parameters_file="$1"
            else
                echo "Error: Unexpected argument '$1'"
                echo "$help_text"
                return 1
            fi
            shift
            ;;
        esac
    done

    # Display help if requested or if required arguments are missing
    if [[ -z "$stack_name" || -z "$template_file" ]]; then
        echo "$help_text"
        return 1
    fi

    if [[ -n "$parameters_file" ]]; then
        aws cloudformation deploy \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "file://${parameters_file}" \
            --stack-name "${stack_name}" --template "${template_file}"
    else
        aws cloudformation deploy \
            --capabilities CAPABILITY_NAMED_IAM \
            --stack-name "${stack_name}" --template "${template_file}"
    fi

}

stack-delete() {
    local help_text="Usage: ${FUNCNAME[0]} [Arguments] [options]

    Arguments:
    stack_name

    Options:
    --force     Force delete a DELETE_FAILED stack
    --help      Display this help message"

    local stack_name="$1"
    local force=0

    # Check if no arguments are provided
    if [[ $# -eq 0 ]]; then
        echo "$help_text"
        return 1
    fi

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -f | --force)
            force=1
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
            if [[ -z "$stack_name" ]]; then
                stack_name="$1"
            else
                echo "Unexpected argument: $1"
                echo "$help_text"
                return 1
            fi
            shift
            ;;
        esac
    done

    cmd="aws cloudformation delete-stack --stack-name ${stack_name} "

    if ((force == 1)); then
        cmd="${cmd} --deletion-mode FORCE_DELETE_STACK"
    fi

    eval "${cmd}"
}
export -f stack-delete
