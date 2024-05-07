#!/usr/bin/env bash

alias ecs-clusters="aws --output json ecs list-clusters | jq -r '.clusterArns[]'"

ecs-services() {
	# returns cluster/service (not full ARN)
	{
		echo "CLUSTER SERVICE"
		ecs-clusters | xargs -P4 -n1 -I {} aws --output json ecs list-services --cluster {} |
			jq -r '.serviceArns[] | sub("^[^/]+/"; "") | sub("/"; " ")'
	} | column -t
}
export -f ecs-services

ecs-tasks() {
	# returns taskId only
	help="provide a cluster as the first argument and a service as the second"

	if [ -z "$1" ]; then
		echo "$help"
		exit 1
	fi

	if [ -z "$2" ]; then
		echo "$help"
		exit 1
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
		exit 1
	fi
	cluster="$1"

	if [ -z "$2" ]; then
		echo "$help"
		exit 1
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
