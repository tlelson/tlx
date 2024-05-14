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

	aws --output json ec2 describe-network-interfaces | jq '[.NetworkInterfaces[] |
		{NetworkInterfaceId, Description, InterfaceType, PrivateIpAddress,
		PublicIP: (.. | .PublicIp? // empty)
		}]
	'

}
export -f enis
