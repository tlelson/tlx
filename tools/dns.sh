#!/usr/bin/env bash

alias hosted-zones="aws --output json route53 list-hosted-zones | jq -r '.HostedZones[].Name' "

# TODO: Make this table-able
record-sets() {
	if [ "$#" -ne 0 ]; then
		hz="$1"
		cmd="aws --output json route53 list-hosted-zones | jq --arg hz \"$hz\" '.HostedZones[] \
				| select(.Name == \"$hz\") | .Id' "
	else
		cmd="aws --output json route53 list-hosted-zones | jq '.HostedZones[] | .Id' "
	fi

	eval "$cmd" | xargs -I {} aws --output json route53 \
		list-resource-record-sets --hosted-zone-id '{}' | jq '[.ResourceRecordSets[] | {Name, Type, Target: (.AliasTarget.DNSName? // .ResourceRecords[].Value) }] | group_by(.Name) |
	map({ Name: .[0].Name, Records: map("\(.Type) \(.Target)") })'

}
export -f record-sets
