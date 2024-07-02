#!/usr/bin/env bash

alias hosted-zones="aws --output json route53 list-hosted-zones | tee /tmp/hz.json | jq -cr '.HostedZones[] | {
    Id, Name, Public: (.Config.PrivateZone | not), RecordSets: .ResourceRecordSetCount}' "
alias record-sets-full='aws --output json route53 list-resource-record-sets --hosted-zone-id '

# TODO: Make this table-able
record-sets() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

    Optional Arguments:
    hosted-zone-name    Filter by hosted zone name.

    Options:
    --help              Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ "$#" -ne 0 ]; then
        hz="$1"
        cmd="aws --output json route53 list-hosted-zones | jq --arg hz \"$hz\" '.HostedZones[] \
                | select(.Name == \"$hz\") | .Id' "
    else
        cmd="aws --output json route53 list-hosted-zones | jq '.HostedZones[] | .Id' "
    fi

    eval "$cmd" | xargs -P4 -I {} aws --output json route53 \
        list-resource-record-sets --hosted-zone-id '{}' | jq -c '.ResourceRecordSets[] | {Name, Type, Target: (.AliasTarget.DNSName? // .ResourceRecords[].Value)}
    '
    #| select(.Type | IN("SOA", "NS") | not)
}
export -f record-sets

alias r53-profiles='aws route53profiles list-profiles'
alias r53-profile-associations='aws route53profiles list-profile-associations'

r53-profile-resource-associations() {
    if [ -z "$1" ]; then
        echo "Must provide a profile ID as an argument"
        return 1
    fi
    aws route53profiles list-profile-resource-associations --profile-id "$1"
}
export -f r53-profile-resource-associations
