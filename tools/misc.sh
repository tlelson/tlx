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
		echo "$help"
		return 1
	fi
	lb="$1"

	aws --output json elbv2 describe-load-balancers --names "$lb" | jq '.LoadBalancers[]'

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
org-units() {
	local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]

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

	aws organizations list-organizational-units-for-parent \
		--query 'OrganizationalUnits[].{Id: Id, Name: Name}' \
		--parent-id "$1"
}
