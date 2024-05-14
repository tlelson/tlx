#!/usr/bin/env bash

alias ecs-clusters="aws --output json ecs list-clusters | jq -r '.clusterArns[]'"

task-def() {
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
	If no task definition is provided a list of active task definitons is returned

	Optional Arguments:
	task-definition	family-name:revision

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi
	if [ -n "$1" ]; then
		aws ecs describe-task-definition --task-definition "$1"
	else
		aws --output json ecs list-task-definitions | jq -r '.taskDefinitionArns[] | sub("^[^/]+/"; "")'
	fi
}
export -f task-def

ecs-service() {
	local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
	If no cluster and service name is provided, a list of services are returned.

	Optional Arguments:
	cluster		ECS Cluster the service is deployed on
	service		Family name of the service

	Options:
	--help       Display this help message"

	# Check if the '--help' flag is present
	if [[ "$*" == *"--help"* ]]; then
		echo "$help_text"
		return 0 # Exit the function after printing help
	fi

	if [ "$#" -ne 2 ]; then
		{
			echo "CLUSTER SERVICE"
			ecs-clusters | xargs -P4 -n1 -I {} aws --output json ecs list-services --cluster {} |
				jq -r '.serviceArns[] | sub("^[^/]+/"; "") | sub("/"; " ")'
		} | column -t
	else
		aws ecs describe-services --cluster "$1" --service "$2"
	fi
}
export -f ecs-service

ecs-tasks() {
	# returns taskId only
	help="provide a cluster as the first argument and a service as the second"

	if [ -z "$1" ]; then
		echo "$help"
		return 1
	fi

	if [ -z "$2" ]; then
		echo "$help"
		return 1
	fi

	aws --output json ecs list-tasks --cluster "$1" \
		--service-name "$2" \
		--desired-status RUNNING | jq -r '.taskArns[] |
		sub(".*/"; "")'
}
export -f ecs-tasks

ecs-shell() {
	help="provide a cluster as the first argument and a service as the second"

	if [ -z "$1" ]; then
		echo "$help"
		return 1
	fi
	cluster="$1"

	if [ -z "$2" ]; then
		echo "$help"
		return 1
	fi
	service="$2"

	taskID=$(ecs-tasks "$cluster" "$service")

	aws --output json ecs execute-command \
		--cluster "$cluster" \
		--task "$taskID" \
		--command "/bin/bash" \
		--interactive
}
export -f ecs-shell
