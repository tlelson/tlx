#!/usr/bin/env bash

ram-their-shares() {
	aws --output json ram list-resources --resource-owner OTHER-ACCOUNTS | jq '.resources'
}

ram-my-shares() {
	resources=$(aws --output json ram list-resources --resource-owner SELF | jq '.resources')
	# TODO: add list of shared principals to this output
	#aws ram list-principals --resource-owner SELF \
	#--query 'principals[].{id: id}' \
	#--resource-share-arns ""
	echo "$resources" | jq
}
