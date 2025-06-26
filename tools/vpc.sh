#!/usr/bin/env bash

## VPC Tools
#
# Tools for managing VPC resources.

_vpc_endpoint_connections() {
    # Describes VPC endpoint connections.
    local help_text="Usage: vpc endpoint-connections [options]
    Lists VPC endpoint connections with their ServiceId, VpcEndpointId, VpcEndpointState, and Name.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    vpc endpoint-connections | jtbl
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws --output json ec2 describe-vpc-endpoint-connections | jq -c '
    .VpcEndpointConnections[] | {
        ServiceId, VpcEndpointId, VpcEndpointState,
        Name: (.Tags | map(select(.Key == "Name")) | .[0].Value)
    }'
}

_vpc_list() {
    # Describes VPCs.
    local help_text="Usage: vpc list [options]
    Lists VPCs with their VpcId, CidrBlock, IsDefault, and Name.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    vpc list | jtbl
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws --output json ec2 describe-vpcs | jq -c '
        .Vpcs[] | {
            VpcId,
            CidrBlock,
            IsDefault,
            Name: (([.Tags[]? | select(.Key=="Name") | .Value] | first) | if . == null then "" else . end)
        }
    '
}

_vpc_subnets() {
    # Describes Subnets.
    local help_text="Usage: vpc subnets [options]
    Lists Subnets with their SubnetId, VpcId, CidrBlock, AvailabilityZone, and Name.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    vpc subnets | jtbl
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws --output json ec2 describe-subnets | jq -c '
        .Subnets[] | {
            SubnetId,
            VpcId,
            CidrBlock,
            AvailabilityZone,
            Name: (([.Tags[]? | select(.Key=="Name") | .Value] | first) // "")
        }
    '
}

_vpc_endpoints() {
    # Describes VPC endpoints.
    local help_text="Usage: vpc endpoints [options]
    Lists VPC endpoints with their VpcEndpointId, VpcEndpointType, VpcId, ServiceName, State, and Name.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    vpc endpoints | jtbl -n
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws --output json ec2 describe-vpc-endpoints | jq -c '.VpcEndpoints[] |
    {
        VpcEndpointId, VpcEndpointType, VpcId, ServiceName, State,
        Name: (.Tags | map(select(.Key == "Name")) | .[0].Value)
    }' | jtbl -n
}

_vpc_endpoint_services() {
    # Describes VPC endpoint services.
    local help_text="Usage: vpc endpoint-services [options]
    Lists VPC endpoint services with their ServiceId, ServiceType, PrivateDnsName, and Name.

    Returns jsonlines.

    Options:
    --help       Display this help message

    Examples:
    vpc endpoint-services | jtbl -n
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    aws ec2 --output json describe-vpc-endpoint-services | jq -c '
    .ServiceDetails[] | {
        ServiceId, ServiceType: .ServiceType[].ServiceType,
        PrivateDnsName,
        Name: (.Tags | map(select(.Key == "Name")) | .[0].Value)
    }' | jtbl -n
}

_vpc_endpoint_approve_pending() {
    # Approves pending VPC endpoint connections.
    local help_text="Usage: vpc approve-pending [options]
    Approves all VPC endpoint connections that are in the 'pendingAcceptance' state.

    Options:
    --help       Display this help message

    Examples:
    vpc approve-pending
    "

    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0
    fi

    local connections
    connections=$(aws --output json ec2 describe-vpc-endpoint-connections | jq -c '
    .VpcEndpointConnections[] | select(.VpcEndpointState=="pendingAcceptance") |
        {ServiceId, VpcEndpointId, VpcEndpointState, Tags}')

    if [[ -z "$connections" ]]; then
        echo "No pending VPC endpoint connections found."
        return 0
    fi

    # Loop through each line of the jq output
    while IFS= read -r line; do
        # Extract ServiceId and VpcEndpointId using jq
        local service_id
        service_id=$(echo "$line" | jq -r '.ServiceId')
        local vpc_endpoint_id
        vpc_endpoint_id=$(echo "$line" | jq -r '.VpcEndpointId')

        # Print the extracted values
        local res
        res=$(aws --output json ec2 accept-vpc-endpoint-connections \
            --service-id "$service_id" \
            --vpc-endpoint-ids "$vpc_endpoint_id" | jq -c)
        echo "Approving: ServiceId: $service_id, VpcEndpointId: $vpc_endpoint_id - $res"
    done <<<"$connections"
}

vpc() {
    local command="$1"
    shift

    case "$command" in
    endpoint-connections)
        _vpc_endpoint_connections "$@"
        ;;
    endpoints)
        _vpc_endpoints "$@"
        ;;
    endpoint-services)
        _vpc_endpoint_services "$@"
        ;;
    approve-pending)
        _vpc_endpoint_approve_pending "$@"
        ;;
    list)
        _vpc_list "$@"
        ;;
    subnets)
        _vpc_subnets "$@"
        ;;
    --help | -h)
        echo "Usage: vpc <command> [options]"
        echo "Commands:"
        echo "  list                   List VPCs"
        echo "  subnets                List Subnets"
        echo "  endpoint-connections   List VPC endpoint connections"
        echo "  endpoints              List VPC endpoints"
        echo "  endpoint-services      List VPC endpoint services"
        echo "  approve-pending        Approve pending VPC endpoint connections"
        echo ""
        echo "Run 'vpc <command> --help' for command-specific help."
        return 0
        ;;
    *)
        echo "Unknown command: $command"
        echo "Run 'vpc --help' for a list of commands."
        return 1
        ;;
    esac
}

# shellcheck disable=SC2068
vpc "$@"
