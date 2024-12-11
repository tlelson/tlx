#!/usr/bin/env bash

## Cloudformation Tools
#
# Tools prefixed by `cfn` are not stack specific.  Tools prefixed by `stack` are stack
# specific and take an argument 'stack_name'.

exports() {
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

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    aws --output json cloudformation list-exports | jq -c '.Exports[] | {
        Stack: .ExportingStackId | sub("^[^/]+/"; "") | sub("/.*$"; ""),
        Name, Value}'
}

resources() {
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

cfn() {
    local command="$1"
    shift

    case "$command" in
    events)
        exports "$@"
        ;;
    failed)
        resources "$@"
        ;;
    --help | -h)
        echo "Usage: stack <command> [options]"
        echo "Commands:"
        echo "  exports      Show stack events"
        echo "  resources    Show failed resources in a stack"
        echo ""
        echo "Run 'cfn <command> --help' for command-specific help."
        ;;
    *)
        echo "Unknown command: $command"
        echo "Run 'cfn --help' for a list of commands."
        return 1
        ;;
    esac
}

cfn "$@"
