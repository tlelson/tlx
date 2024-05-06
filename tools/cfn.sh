#!/usr/bin/env bash

## Cloudformation Tools
#
# Tools prefixed by `cfn` are not stack specific.  Tools prefixed by `stack` are stack
# specific and take an argument 'stack_name'.

cfn-exports() {
	# This returns all cfn exports.  It takes an optional argument that filters
	# by glob pattern
	# E.g:
	#	cfn-exports
	#	cfn-exports 'subnet'

	cmd='aws --output json cloudformation list-exports'

	if [ "$#" -ne 0 ]; then
		cmd="${cmd} | jq '.Exports[] | select(.Name|test(\".*${*}.*\"))'"
	else
		cmd="${cmd} | jq '.Exports[]'"
	fi

	eval "$cmd"
}

cfn-resources() {
	# This returns all resources deployed by all cfn stacks.  It takes an optional argument
	# that defines the level of concurrency.
	# E.g:
	#	cfn-resources			# Uses 32 concurrent processes
	#	cfn-resources 4			# Uses  4 concurrent processes

	concurrency=32

	if [ -n "$2" ]; then
		concurrency="$2"
	fi

	## Parrallel

	task() {
		aws --output json cloudformation list-stack-resources --stack-name "$1" |
			jq -c --arg stack_name "$1" '.StackResourceSummaries[] | {StackName: $stack_name, ResourceType, PhysicalResourceId, LogicalResourceId}'
	}

	stacks=$(aws --output json cloudformation list-stacks | jq -r '.StackSummaries[] | select(.StackStatus != "DELETE_COMPLETE") | .StackName')

	(
		for stack_name in ${stacks}; do
			((i = i % concurrency)) # Exits with i. Can't exit on first error
			((i++ == 0)) && wait
			#echo "${stack_name}" &
			task "${stack_name}" &
		done
	)

}

stack-events() {
	event_limit=10

	if [ -z "$1" ]; then
		echo "provide a stack name as the first argument"
		exit 1
	fi

	if [ -n "$2" ]; then
		event_limit="$2"
	fi

	#aws --output json cloudformation describe-stack-events --stack-name "$1" \
	#--max-items "${event_limit}" --query 'StackEvents[*].[LogicalResourceId, ResourceType, ResourceStatus, ResourceStatusReason]' --output table

	aws --output json cloudformation describe-stack-events --stack-name "$1" \
		--max-items "${event_limit}" | jq '.StackEvents | map({
		ResourceType, LogicalResourceId, ResourceStatus, Timestamp, ResourceStatusReason })'

}

stack-failed() {
	if [ -z "$1" ]; then
		echo "provide a stack name as the first argument"
		exit 1
	fi
	stack_name="$1"

	stack-events "$stack_name" 50 | jq '
		.[] | select(.ResourceStatus|test(".*FAILED")) '
}

stack-params() {

	if [ -z "$1" ]; then
		echo "Output is JSON by default because the output may be used as input for deploy."
		echo "${FUNCNAME[0]} \$stack_name | jtbl"
		exit 1
	fi
	stack_name="$1"

	aws --output json cloudformation describe-stacks --stack-name "$stack_name" |
		jq -r '.Stacks[0].Parameters'

}

stack-status() {

	stack_status=$(aws --output json cloudformation list-stacks |
		jq -rc '.StackSummaries[] | [ .StackName[:60], .StackStatus] | @tsv' |
		grep -v 'DELETE_COMPLETE')

	{
		echo "STACKNAME STATUS"
		if [ "$#" -ne 0 ]; then
			echo "$stack_status" | grep --color=auto "$*"
		else
			echo "$stack_status"
		fi
	} | column -t

}
