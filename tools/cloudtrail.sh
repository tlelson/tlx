#!/usr/bin/env bash

cloudtrail-query() {
    # Define default values for the optional parameters
    local start=""
    local end=""
    local event_name=""
    local event_source=""
    local resource_type=""
    local username=""
    local full_history="false"
    local event_pattern=""

    # Help message
    help_text="Usage: cloud-trail-query [OPTIONS]

    Returns cloudtrail event summary matching the provided optional filter arguments.
    If no filters are supplied the query will take a long time. It is strongly advised that
    some filters be provided.

    To prevent accidental requests of all data, the --full-history flag is required if no other
    filters are provided.

    Query parameters (these reduce response size and time):
    Zero, some or All of:
        -s, --start            Start date. Default 90 days ago. e.g 'May 10', '30 mins ago'
        -e, --end              End date. Default: now. e.g 'May 10', '30 mins ago'

    Zero or One of:
        -n, --event-name       Event name. e.g 'PutApprovalResult'
        -o, --event-source     Event source. e.g 's3.amazonaws.com'
        -r, --resource-type    Resource type. e.g 'AWS::KMS::Key'
        -u, --username         Username. e.g 'john.smith@company.com'

    Filter parameters (post-response):
        -p, --event-pattern    A text pattern to filter events by. e.g 'Prod'

    Other Options:
        --full-history     Retrieve full history. Required IFF no other args are provided.
        --help             Display this help message"

    # Check if no arguments are provided
    if [[ $# -eq 0 ]]; then
        echo "$help_text"
        return 1
    fi

    local count_exclusive=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s | --start)
            start="$2"
            shift 2
            ;;
        -e | --end)
            end="$2"
            shift 2
            ;;
        -n | --event-name)
            event_name="$2"
            count_exclusive=$((count_exclusive + 1))
            shift 2
            ;;
        -p | --event-pattern)
            event_pattern="$2"
            shift 2
            ;;
        -o | --event-source)
            event_source="$2"
            count_exclusive=$((count_exclusive + 1))
            shift 2
            ;;
        -t | --resource-type)
            resource_type="$2"
            count_exclusive=$((count_exclusive + 1))
            shift 2
            ;;
        -u | --username)
            username="$2"
            count_exclusive=$((count_exclusive + 1))
            shift 2
            ;;
        --full-history)
            full_history="true"
            shift
            ;;
        --help)
            echo "$help_text"
            return 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            return 1
            ;;
        esac
    done

    # Check if more than one exclusive option is provided
    if [[ $count_exclusive -gt 1 ]]; then
        echo "Error: Only one of --event-name, --event-source, --resource-type, or --username can be specified at a time." >&2
        return 1
    fi

    # Here you can add your logic to process the events using the provided parameters
    cmd='aws --output json cloudtrail lookup-events '

    if [ -n "$start" ]; then
        s=$(date -d"$start" +%s)
        cmd="$cmd --start-time $s "
    fi
    if [ -n "$end" ]; then
        e=$(date -d"$end" +%s)
        cmd="$cmd --end-time $e "
    fi
    if [ -n "$event_name" ]; then
        cmd="$cmd --lookup-attributes AttributeKey=EventName,AttributeValue=$event_name"
    elif [ -n "$event_source" ]; then
        cmd="$cmd --lookup-attributes AttributeKey=EventSource,AttributeValue=$event_source"
    elif [ -n "$resource_type" ]; then
        cmd="$cmd --lookup-attributes AttributeKey=ResourceType,AttributeValue=$resource_type"
    elif [ -n "$username" ]; then
        cmd="$cmd --lookup-attributes AttributeKey=Username,AttributeValue=$username "
    fi

    event_file='/tmp/cloudtrail-events.json'
    results=$(eval "$cmd" | tee "$event_file")

    formatter=".Events[]"

    if [ -n "${event_pattern}" ]; then
        formatter="$formatter | select(.CloudTrailEvent|test(\"${event_pattern}\"))"
    fi

    formatter="$formatter | { EventTime, EventName, Username, EventId}"
    echo "$results" | jq -c "${formatter}"

    return 0
}
export -f cloudtrail-query

cloudtrail-event() {
    local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]

    Arguments:
    event_id    cloudtrail event id.

    Options:
    --help      Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [[ $# -eq 0 ]]; then
        echo "$help_text"
        return 1
    fi

    event_file='/tmp/cloudtrail-events.json'
    event_id="$1"
    result=$(jq --arg id "$event_id" '.Events[] |
        select(.EventId==$id) | .CloudTrailEvent | fromjson' "$event_file")

    if [ -z "$result" ]; then
        echo "event_id not Found in: $event_file. Run cloudtrail-query first to get event_id"
        return 1
    fi

    echo "$result" | jq

}
