#!/usr/bin/env bash

alias aws-who-am-i='aws-list-accounts | grep "$(aws --output json sts get-caller-identity | jq -r "'".Account"'")"'

alias security-groups="aws --output json ec2 describe-security-groups | jq -c '.SecurityGroups[] | {GroupId, GroupName, Description}'"

security-group-rules() {
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
	If security group is provided, all rules are returned.

	Optional Arguments:
	security-group-id	e.g sg-XXXX

	Options:
	--help       Display this help message"

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
	loadbalancer_names	comma seperated list of load balancer names

	Options:
	--help       Display this help message"

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

enis() {
	# Use aws ec2 describe-network-interfaces --filters to get details. Its actually very
	# good.

	aws --output json ec2 describe-network-interfaces | tee /tmp/enis.json | jq '[.NetworkInterfaces[] |
		{NetworkInterfaceId, InterfaceType, PrivateIpAddress,
		PublicIP: (.. | .PublicIp?), Description,
		}] | sort_by(.PrivateIpAddress)
	'
}
export -f enis

nacls() {
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
	Normally we are looking NACLs to find why our traffic is blocked.  In this case supply
	the subnet. If no subnet is provided a list of NACLs will be returned.

	Optional Arguments:
	subnet	subnet associations to filter by

	Options:
	--help       Display this help message"

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
			--query 'NetworkAcls[]' |
			tee /tmp/dnacls.json | jq '[.[] | {
                Name: (.Tags | map(select(.Key == "Name")) | .[0].Value),
                VpcId, Subnets: [.Associations[].SubnetId],
            }]'
	fi
}
export -f nacls
