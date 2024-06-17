#!/usr/bin/env bash

alias hosted-zones="aws --output json route53 list-hosted-zones | tee /tmp/hz.json | jq -cr '.HostedZones[] | {
    Id, Name, Public: (.Config.PrivateZone | not), RecordSets: .ResourceRecordSetCount}' "
alias record-sets-full='aws --output json route53 list-resource-record-sets --hosted-zone-id '

# TODO: Make this table-able
record-sets() {
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
