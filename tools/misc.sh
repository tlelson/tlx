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

alias accounts="aws --output json organizations list-accounts | jq -c '.Accounts[] | del(.Arn, .JoinedMethod)' | jtbl"
alias roots="aws organizations list-roots"

scps() {
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]

	Optional Arguments:
	target-id	Root, OU or Account id to filter by

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi

	if [ -z "$1" ]; then
		aws --output json organizations list-policies \
			--query 'Policies[].{Id: Id, Name: Name, Description: Description,
				AwsManaged: AwsManaged}' \
			--filter 'SERVICE_CONTROL_POLICY' | jtbl
	else
		aws --output json organizations list-policies-for-target \
			--target-id "$1" \
			--query 'Policies[].{Id: Id, Name: Name, Description: Description,
				AwsManaged: AwsManaged}' \
			--filter 'SERVICE_CONTROL_POLICY' | jtbl
	fi

}
export -f scps

org-units() {
	local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]
	Output: JSON (usefull to pick names out and recurse)

	Arguments:
	target-id	Root OU. (use 'roots' to list)

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

	aws --output json organizations list-organizational-units-for-parent \
		--query 'OrganizationalUnits[].{Id: Id, Name: Name}' \
		--parent-id "$1"
}
export -f org-units

# Left here for reference.  Its a good example of building up a JSON object
# in bash and other bash tricks.
# It is however very slow.  The async python version is ~6 times faster.
_org-tree() {
	# TODO: Speed up (python? go?)
	# Add accounts and SCPs to each org-unit

	root=$(aws --output json organizations list-roots | jq -r '.Roots[] | select(.Name=="Root") | .Id ')

	orgs=$(org-units "$root" | jq -c '.[]') # jsonlines for loop to read.

	tree='[]'
	while IFS= read -r obj; do
		id=$(echo "$obj" | jq -r '.Id')
		children=$(org-units "$id")
		updated_obj=$(echo "$obj" | jq --argjson children "$children" '.Children = $children')
		tree=$(jq --argjson updated_obj "$updated_obj" '. + [$updated_obj] ' <<<"$tree")

	done <<<"$orgs"

	tree='{"Id":"'"$root"'","Children":'"$tree"'}'
	echo "$tree"
}
