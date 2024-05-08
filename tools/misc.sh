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
		exit 1
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
