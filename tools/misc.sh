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

    cmd="aws --output json ec2 describe-security-group-rules"
    # Add filters if $1 is empty (meaning no argument provided)
    if [ -n "$1" ]; then
        cmd+=" --filters \"Name=group-id,Values=$1\""
    fi

    # Execute the constructed command string
    eval "$cmd" | jq '.SecurityGroupRules'

    # TODO: return like this but add target (either CidrIpv4 or Security group)
    #security-group-rules | jq -c '.[] | {GroupId, IsEgress, Proto: .IpProtocol, From: .FromPort, To: .To
    #Port?}' | jtbl

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

apis() {

    # TODO: If arg given
    #aws --output json apigateway get-rest-api --rest-api-id "$api_id" | jq

    res=$(aws --output json apigateway get-rest-apis | jq -c '.items[] | {id, name,
        created: .createdDate | sub(":[0-9]{2}\\.[0-9]{6}";""),
        type: .endpointConfiguration.types | join(","),
        vpcEndpointIds: (if .endpointConfiguration.vpcEndpointIds then
            .endpointConfiguration.vpcEndpointIds | join(",")
        else
            null
        end)
    }')

    concurrency=32

    task() {
        obj="$1"
        api_id=$(echo "$obj" | jq -r '.id')
        #api_id='53ahy0oiuf'
        ls=$(aws apigateway get-stages --rest-api-id "$api_id" \
            --query 'item' | jq -r 'sort_by(.createdDate) | last | .stageName')
        line=$(jq -c -n --argjson obj "$obj" --arg ls \
            "$ls" '$obj + {latest_stage: $ls}')
        echo "$line"
    }

    (
        pids=()
        while IFS= read -r obj; do
            ((i = i % concurrency)) # Exits with i. Can't exit on first error
            ((i++ == 0)) && wait
            task "$obj" &
            pids+=($!)
        done <<<"$res"

        # Wait for all backgrounded tasks
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
    )

}
export -f apis

api-url() {
    api_id="$1"
    stage="$2"
    echo "https://$api_id.execute-api.$AWS_REGION.amazonaws.com/$stage"
}

# TODO: write file to STDOUT
#api-stage-schema() {
#aws apigateway get-export \
#--rest-api-id "$api_id" \
#--stage-name "$stage_name" \
#--export-type "oas30"  outfile.json

#- | jq
#}

apig-custom-domains() {
    res=$(aws --output json apigateway get-domain-names | jq -c '.items[] | {
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
    }')

    concurrency=32

    task() {
        obj="$1"
        domain_name=$(echo "$obj" | jq -r '.domainName')
        api_deets=$(aws --output json apigateway get-base-path-mappings \
            --domain-name "$domain_name" | jq '.items[] ')
        line=$(jq -c -n --argjson obj "$obj" --argjson api_deets "$api_deets" '$obj + $api_deets')
        echo "$line"
    }

    (
        pids=()
        while IFS= read -r obj; do
            ((i = i % concurrency)) # Exits with i. Can't exit on first error
            ((i++ == 0)) && wait
            task "$obj" &
            pids+=($!)
        done <<<"$res"

        # Wait for all backgrounded tasks
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
    )
}
export -f apig-custom-domains
