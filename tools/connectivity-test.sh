#!/usr/bin/env bash

connectivity-test() {
    local help_text="Usage: ${FUNCNAME[0]} [Optional Arguments]
    If no argument is provided, a lists of existing connectivity tests is returned.

    Returns jsonlines if no arg is provided or structured json if a path_id is provided.

    Optional Arguments
    path_id         If provided, this will give details of the specific test

    Options:
    --help          Display this help message

    Examples:
    ${FUNCNAME[0]} | jtbl
    ${FUNCNAME[0]} nip-09cdd81bef5ac6dc6
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi
    if [ -z "$1" ]; then
        aws --output json ec2 describe-network-insights-paths | jq -rc '.NetworkInsightsPaths[] | {
            Name: (.Tags | map(select(.Key == "Name")) | .[0].Value),
            PathId: .NetworkInsightsPathId,
    }'
    else
        pid="$1"
        aws --output json ec2 describe-network-insights-paths \
            --network-insights-path-ids "$pid" | jq '
                    .NetworkInsightsPaths[0]'
    fi
}
export -f connectivity-test

connectivity-test-start() {
    local help_text="Usage: ${FUNCNAME[0]} [Arguments]
    Start an analysis.

    Use 'connectivity-tests' to find the test you want

    Arguments
    path_id             Use 'connectivity-tests'

    Options:
    --help           Display this help message

    Example:
    ${FUNCNAME[0]} nip-XXX | jtbl
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi
    if [ -z "$1" ]; then
        echo "$help_text"
        return 1
    fi

    path_id="$1"

    aws --output json ec2 start-network-insights-analysis \
        --network-insights-path-id "$path_id" | jq -c '.NetworkInsightsAnalysis | {
            Execution_ID: .NetworkInsightsAnalysisId,
            StartDate, Status,
        }'

}

# TODO: Think about merging these
connectivity-test-execution() {
    local help_text="Usage: ${FUNCNAME[0]} [Arguments] [Optional Arguments] [Options]
    List previous analyses (jsonlines). Or Details of a specific execution (called
    'path analyses' in aws lingo). This returns structured JSON.

    Use 'connectivity-tests' to find the test you want

    Arguments:
    path_id         Use 'connectivity-tests'

    Optional Arguments:
    execution_id    Use 'connectivity-test-runs' to find latest.

    Options:
    --help          Display this help message

    Example:
    ${FUNCNAME[0]} nip-0530dc82736235d97 | jtbl
    ${FUNCNAME[0]} \$nip \$nia
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -z "$1" ]; then
        echo "$help_text"
        return 1
    fi
    path_id="$1"

    if [ -z "$2" ]; then
        aws --output json ec2 describe-network-insights-analyses \
            --network-insights-path-id "$path_id" | tee /tmp/ctr.json | jq -c '.NetworkInsightsAnalyses |
            sort_by(.StartDate) | reverse | .[] | {
            StartDate,
            AnalysisId: .NetworkInsightsAnalysisId,
            Status,
            NetworkPathFound,
        }'
        return 0
    fi
    execution_id="$2"

    aws --output json ec2 describe-network-insights-analyses \
        --network-insights-path-id "$path_id" \
        --network-insights-analysis-ids "$execution_id" | jq
}
export -f connectivity-test-execution

connectivity-test-delete() {
    aws --output json ec2 delete-network-insights-path \
        --network-insights-path-id "$path_id" >/dev/null
}
