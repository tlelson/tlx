alias hosted-zones="aws route53 list-hosted-zones | jq -r '.HostedZones[].Name' "
alias vpc-endpoint-connections="aws ec2 describe-vpc-endpoint-connections | jq -c '
  .VpcEndpointConnections[] | { ServiceId, VpcEndpointId, VpcEndpointState, Tags}'
"
