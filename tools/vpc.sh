#!/usr/bin/env bash

alias vpc-endpoint-connections="aws --output json ec2 describe-vpc-endpoint-connections | jq -c '
	.VpcEndpointConnections[] | {
	ServiceId, VpcEndpointId, VpcEndpointState,
	Name: (.Tags | map(select(.Key == \"Name\")) | .[0].Value)
}'"

alias vpc-endpoints="aws --output json ec2 describe-vpc-endpoints | jq -c '.VpcEndpoints[] |
	{
		VpcEndpointId, VpcEndpointType, VpcId, ServiceName, State,
		Name: (.Tags | map(select(.Key == \"Name\")) | .[0].Value)
	}' | jtbl -n"

alias vpc-endpoint-services="aws ec2 --output json describe-vpc-endpoint-services | jq -c '
	.ServiceDetails[] | {
		ServiceId, ServiceType: .ServiceType[].ServiceType,
		PrivateDnsName,
		Name: (.Tags | map(select(.Key == \"Name\")) | .[0].Value),
	}' | jtbl -n "

vpc-endpoint-approve-pending() {
	aws --output json ec2 describe-vpc-endpoint-connections | jq -c '.VpcEndpointConnections[] |
        select(.VpcEndpointState=="pendingAcceptance") |
            {ServiceId, VpcEndpointId, VpcEndpointState, Tags}' >/tmp/dvec.json

	# Loop through each line of the jq output
	while IFS= read -r line; do
		# Extract ServiceId and VpcEndpointId using jq
		service_id=$(echo "$line" | jq -r '.ServiceId')
		vpc_endpoint_id=$(echo "$line" | jq -r '.VpcEndpointId')

		# Print the extracted values
		echo "Approving: ServiceId: $service_id, VpcEndpointId: $vpc_endpoint_id"
		aws --output json ec2 accept-vpc-endpoint-connections --service-id "$service_id" \
			--vpc-endpoint-ids "$vpc_endpoint_id" | jq

	done </tmp/dvec.json
}
export -f vpc-endpoint-approve-pending
