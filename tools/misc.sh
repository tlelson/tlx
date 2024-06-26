#!/usr/bin/env bash

alias watch='watch -n5 --exec bash -c ' # Need this to run these tools in watch
alias aws-who-am-i='aws-list-accounts | grep "$(aws --output json sts get-caller-identity | jq -r "'".Account"'")"'

alias security-groups="aws --output json ec2 describe-security-groups | jq -c '.SecurityGroups[] | {GroupId, GroupName, Description}'"

security-group-rules() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    If security group is provided, all rules are returned.

    Optional Arguments:
    security-group-id   e.g sg-XXXX

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    cmd="aws ec2 describe-security-group-rules"
    # Add filters if $1 is empty (meaning no argument provided)
    if [ -n "$1" ]; then
        cmd+=" --filters \"Name=group-id,Values=$1\""
    fi

    # Execute the constructed command string
    eval "$cmd"

}
export -f security-group-rules

alias load-balancers="aws --output json elbv2 describe-load-balancers | jq -r '.LoadBalancers[].LoadBalancerName' "

load-balancer() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

    Optional Arguments:
    loadbalancer_names  comma seperated list of load balancer names

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -z "$1" ]; then
        echo "$help_text"
        return 1
    fi
    lb="$1"

    aws --output json elbv2 describe-load-balancers --names "$lb" | jq -c '.LoadBalancers[]'

}
export -f load-balancer

alias eni='aws ec2 describe-network-interfaces --network-interface-ids '

enis() {
    local help_text="Usage: ${FUNCNAME[0]} [options]
    Lists ENI's in the current account. For more detail on a specific ENI use the aws cli
    command. Its actually very good. See also '--filters'

    aws ec2 describe-network-interfaces --network-interface-ids \"\$eniID\"

    Returns jsonlines

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    aws --output json ec2 describe-network-interfaces | tee /tmp/enis.json | jq -c '[.NetworkInterfaces[] |
        {NetworkInterfaceId, InterfaceType, PrivateIpAddress, SubnetId,
        PublicIP: [.. | .PublicIp?] | map(select(. != null)) | unique |.[0] ,
        Description,
        }] | sort_by(.PrivateIpAddress) | .[]
    '
}
export -f enis

nacls() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    Normally we are looking NACLs to find why our traffic is blocked.  In this case supply
    the subnet. If no subnet is provided a list of NACLs will be returned.

    Optional Arguments:
    subnet  subnet associations to filter by

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -n "$1" ]; then
        aws --output json ec2 describe-network-acls \
            --query 'NetworkAcls[].{Entries: Entries}' \
            --filters "Name=association.subnet-id,Values=$1" | jq '[.[].Entries[] | {
                CidrBlock, Egress, PortRange: "\(.PortRange.From) - \(.PortRange.To)", Protocol, RuleAction, RuleNumber
            }] | sort_by(.RuleNumber)'
    else
        aws --output json ec2 describe-network-acls \
            --query 'NetworkAcls[]' | jq '[.[] | {
                Name: (.Tags | map(select(.Key == "Name")) | .[0].Value),
                VpcId, Subnets: [.Associations[].SubnetId],
            }]'
    fi
}
export -f nacls

alias profiles='aws route53profiles list-profiles'
alias profile-associations='aws route53profiles list-profile-associations'

profile-resource-associations() {
    if [ -z "$1" ]; then
        echo "Must provide a profile ID as an argument"
        return 1
    fi
    aws route53profiles list-profile-resource-associations --profile-id "$1"
}
export -f profile-resource-associations

params() {
    aws ssm describe-parameters --query "Parameters[*].[Name,Type,LastModifiedDate,Version]" --output table
}
export -f params

lambda() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    If no name is provided a list of lambdas is returned.

    Arguments
    lambda_name

    Options:
    --help           Display this help message

    Output:
    jsonlines if no name is provided or structured json if single lambda name provided.

    Examples:
    lambda | grep alert | jtbl
    lambda alert-dev

    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -z "$1" ]; then
        aws --output json lambda list-functions | jq -c '.Functions[] | {
            FunctionName, Runtime,
            LastModified,
            LogGroup: .LoggingConfig.LogGroup,
        }'
    else
        aws --output json lambda get-function-configuration --function-name "$1" | jq
    fi
}
export -f lambda

cloudfront() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

    Optional Arguments
    distribution_id

    Options:
    --help           Display this help message

    Output:
    jsonlines if no id is provided or structured json otherwise.

    Examples:
    ${FUNCNAME[0]} | jtbl
    ${FUNCNAME[0]} E1BNGBGT8NQOPL | jq

    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    if [ -z "$1" ]; then
        aws --output json cloudfront list-distributions | tee /tmp/cfnt.json | jq -c '
            .DistributionList.Items[]| {Id, DomainName, Status,
            Modified: .LastModifiedTime | sub(":[0-9]{2}\\.[0-9]{6}";"")
        }'
        return 0
    fi

    aws cloudfront get-distribution --id "$1" | jq
}
export -f cloudfront

apig() {
    # TODO: If id is provided, describe in details with:
    #   - Active stage url
    #   - API schema
    #   - direct link to resource in web console

    aws --output json apigateway get-rest-apis | jq -c '.items[] | {id, name,
        created: .createdDate | sub(":[0-9]{2}\\.[0-9]{6}";""),
        type: .endpointConfiguration.types | join(","),
        vpcEndpointIds: (if .endpointConfiguration.vpcEndpointIds then
            .endpointConfiguration.vpcEndpointIds | join(",")
        else
            null
        end)
    }'
}

apig-custom-domains() {
    aws --output json apigateway get-domain-names | jq -c '.items[] | {
        domainName,
        type: (.endpointConfiguration.types | join(",")),
        target: (
            if .endpointConfiguration.types[0] == "REGIONAL" then
                .regionalDomainName
            elif .endpointConfiguration.types[0] == "EDGE" then
                .distributionDomainName
            else
                "unknown type"
            end
        ),
        zoneId: (
            if .endpointConfiguration.types[0] == "REGIONAL" then
                .regionalHostedZoneId
            elif .endpointConfiguration.types[0] == "EDGE" then
                .distributionHostedZoneId
            else
                "unknown type"
            end
        ),
    }'

    # TODO: Add apiId from command below to output
    #aws --output json apigateway get-base-path-mappings --domain-name 'storybook.osfin.ca' | jq '
    #.items[]
    #'
}
