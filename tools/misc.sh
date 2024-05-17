#!/usr/bin/env bash

alias watch='watch -n5 --exec bash -c ' # Need this to run these tools in watch
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

alias eni='aws ec2 describe-network-interfaces --network-interface-ids '

enis() {
	local help_text="Usage: ${FUNCNAME[0]} [options]
	Lists ENI's in the current account. For more detail on a specific ENI use the aws cli
	command. Its actually very good. See also '--filters'

	aws ec2 describe-network-interfaces --network-interface-ids \"\$eniID\"

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi

	aws --output json ec2 describe-network-interfaces | tee /tmp/enis.json | jq '[.NetworkInterfaces[] |
		{NetworkInterfaceId, InterfaceType, PrivateIpAddress,
		PublicIP: [.. | .PublicIp?] | map(select(. != null)) | unique |.[0] ,
		Description,
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

alias profiles='aws route53profiles list-profiles'
alias profile-associations='aws route53profiles list-profile-associations'

profile-resource-associations() {
	if [ -z "$1" ]; then
		echo "Must provide a profile ID as an argument"
		return 1
	fi
	aws route53profiles list-profile-resource-associations --profile-id "$1"
}

connectivity-test() {
	local help_text="Usage: ${FUNCNAME[0]} [Optional Arguments]
	If no argument is provided, a lists of existing connectivity tests is returned.

	Optional Arguments
	testID		If provided, this will give details of the specific test

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi
	if [ -z "$1" ]; then
		aws --output json ec2 describe-network-insights-paths | jq -rc '.NetworkInsightsPaths[] | {
			Name: (.Tags | map(select(.Key == "Name")) | .[0].Value),
			Id: .NetworkInsightsPathId,
	}'
	else
		tid="$1"
		aws --output json ec2 describe-network-insights-paths \
			--network-insights-path-ids "$tid" | jq '
					.NetworkInsightsPaths[0]'
	fi
}

connectivity-test-runs() {
	if [ -z "$1" ]; then
		echo "Must provide a connectivity test ID as an argument"
		return 1
	fi

	aws --output json ec2 describe-network-insights-analyses --network-insights-path-id "$1" | tee /tmp/nia.json | jq -c '.NetworkInsightsAnalyses |
		sort_by(.StartDate)| .[] |  {
		StartDate,
		AnalysisId: .NetworkInsightsAnalysisId,
		Status,
		NetworkPathFound,
	}'
}

connectivity-test-run() {
	local help_text="Usage: ${FUNCNAME[0]} [Arguments]
	Details of a specific analysis.

	Use 'connectivity-tests' to find the test you want

	Arguments
	testID		Use 'connectivity-tests'
	testRunID	Use 'connectivity-test-runs' to find latest.

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi

	if [ "$#" -ne 2 ]; then
		echo "$help_text"
		return 1
	fi

	aws ec2 describe-network-insights-analyses \
		--network-insights-path-id "$1" \
		--network-insights-analysis-ids "$2"
}
