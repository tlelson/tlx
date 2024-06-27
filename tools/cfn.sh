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
    local help_text="Usage: ${FUNCNAME[0]} [options]
    Returns all cloudformation exports.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    ${FUNCNAME[0]} | grep 'subnet' | jtbl
    "

    aws --output json cloudformation list-exports | jq -c '.Exports[] | {
        Stack: .ExportingStackId | sub("^[^/]+/"; "") | sub("/.*$"; ""),
        Name, Value}'
}
export -f cfn-exports

cfn-resources() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    This can be a slow operation since it scans all resources from all Cloudformation stacks. Therfore the default concurrency is 32.  If you have errors or are running this over many accounts similtaneously you may need to reduce concurrency.

    Returns jsonlines.

    Optional Arguments:
    concurrency  e.g 4 (default 32)

    Options:
    --help       Display this help message

    Examples:
    ${FUNCNAME[0]} | grep 'IAM::Role' | jtbl
    "

    # This returns all resources deployed by all cfn stacks.  It takes an optional argument
    # that defines the level of concurrency.
    # E.g:
    #   cfn-resources           # Uses 32 concurrent processes
    #   cfn-resources 4         # Uses  4 concurrent processes

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

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
        #pids=()
        for stack_name in ${stacks}; do
            ((i = i % concurrency)) # Exits with i. Can't exit on first error
            ((i++ == 0)) && wait
            task "${stack_name}" &
            #pids+=($!)
        done

        # Can't do this and pipe to head etc
        # Wait for all backgrounded tasks
        #for pid in "${pids[@]}"; do
        #wait "$pid"
        #done
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
    local help_text="Usage: ${FUNCNAME[0]} [options]
    Returns jsonlines.

    Options:
    --help                  Display this help message

    Examples:
    ${FUNCNAME[0]} | grep 'alert' | jtbl
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws --output json cloudformation list-stacks |
        jq -c '.StackSummaries[] | select(.StackStatus!="DELETE_COMPLETE") | {
            StackName, StackStatus,
            Updated: (.LastUpdatedTime // .CreationTime | sub(":[0-9]{2}\\.[0-9]{6}"; ""))
        }'

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

stack-resources() {
    local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]
    Returns a list of the deployed resources of a stack

    Returns jsonlines.

    Arguments:
    stack_name

    Options:
    --help       Display this help message

    Examples:
    ${FUNCNAME[0]} 'stack-name' | grep 'IAM::Role' | jtbl
    "

    if [ -z "$1" ]; then
        echo "provide a stack name as the first argument"
        return 1
    fi

    stack_name="$1"

    aws --output json cloudformation list-stack-resources \
        --stack-name "$stack_name" | jq -c '
            .StackResourceSummaries[] | {ResourceType, PhysicalResourceId, LogicalResourceId}'
}

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

    local stack_name=""
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
