#!/usr/bin/env bash

hosted_zones() {
    if [[ "$1" == "--help" ]]; then
        echo "Usage: hosted_zones"
        echo "Lists AWS Route 53 hosted zones along with associated VPCs (if any)."
        return 0
    fi

    concurrency=32

    task() {
        hostedZone="$1"

        # Extract hosted zone ID
        hostedZoneId=$(echo "$hostedZone" | jq -r .Id)

        # Fetch VPCs associated with the hosted zone
        vpcs=$(aws --output json route53 get-hosted-zone --id "$hostedZoneId" |
            jq -c '[.VPCs[] | "\(.VPCId) (\(.VPCRegion))"] | join(",")')

        # Append VPCs to the hosted zone JSON object
        echo "$hostedZone" | jq -c --argjson vpcs "$vpcs" '. + {VPCs: $vpcs}'

    }

    (
        # Fetch hosted zones and store in temporary file
        aws --output json route53 list-hosted-zones | jq -cr '.HostedZones[] | {
        Id, Name, Public: (.Config.PrivateZone | not), RecordSets: .ResourceRecordSetCount }' | while read -r hostedZone; do
            ((i = i % concurrency)) # Exits with i. Can't exit on first error
            ((i++ == 0)) && wait
            task "$hostedZone" &
        done
    )
}
export -f hosted_zones

# Add this to display help message when needed
alias hosted-zones="hosted_zones"

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
