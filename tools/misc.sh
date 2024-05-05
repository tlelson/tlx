alias vpc-endpoint-connections="aws ec2 describe-vpc-endpoint-connections | jq -c '
  .VpcEndpointConnections[] | { ServiceId, VpcEndpointId, VpcEndpointState, Tags}'
"
