#!/usr/bin/env bash

iam-role-policy() {
    local help_text="Usage: ${FUNCNAME[0]} [ARGS] [options]
    Show details of a role policy. This is distinct from an attached policy. Use 'iam-policy' for those.

    Optional Arguments:
    role_name
    policy_name

    Options:
    --help           Display this help message

    Examples:
    iam-role-policy \$r \$p | jq '.PolicyDocument' | tee /tmp/\$p.json | jq

    # Update it with
    aws iam put-role-policy --role-name \$r --policy-name \$p --policy-document file:///tmp/\$p.json
    "

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ "$#" -ne 2 ]; then
        echo "$help_text"
        return 1
    fi

    aws --output json iam get-role-policy --role-name "$1" --policy-name "$2" | jq
}
export -f iam-role-policy

iam-role() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    Without a role name (not ARN) a list of IAM Roles are returned. If a name
    is provided, details of the role are returned.

    use 'iam-policy' to view AttachedPolicies.

    use 'iam-role-policy' to view RolePolicies.

    Optional Arguments:
    role_name

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -z "$1" ]; then
        aws --output json iam list-roles | jq -r '.Roles[].Arn | split("/") | .[1]'
    else
        role_name="$1"

        attached_policies=$(aws --output json iam list-attached-role-policies \
            --role-name "$role_name" &)

        role_policies=$(aws --output json iam list-role-policies \
            --role-name "$role_name" | jq -cr '.PolicyNames' &)

        get_role=$(aws --output json iam get-role --role-name "$role_name" |
            jq '.Role')

        wait # For 3 calls to complete

        echo "$get_role" |
            jq --argjson rp "$role_policies" '. + {"RolePolicies": $rp}' |
            jq ". += $attached_policies"
    fi
}
export -f iam-role

iam-policy() {
    local help_text="Usage: ${FUNCNAME[0]} [OPTIONAL_ARGS] [options]
    Without a policy ARN a list of IAM Policy Arns is returned. If an ARN is provided, the policy document of the latest version is returned.

    Optional Arguments:
    policyArn   ARN of the IAM role

    Options:
    --help           Display this help message"

    # Check if the '--help' flag is present
    if [[ "$*" == *"--help"* ]]; then
        echo "$help_text"
        return 0 # Exit the function after printing help
    fi

    if [ -z "$1" ]; then
        aws iam list-policies \
            --query 'Policies[*].[PolicyName, Arn, DefaultVersionId]'
    else
        arn="$1"
        versionId=$(aws --output json iam get-policy --policy-arn "$arn" \
            --query 'Policy.DefaultVersionId' | jq -r)
        aws --output json iam get-policy-version --policy-arn "$arn" \
            --version-id "$versionId" --query 'PolicyVersion.Document' | jq
    fi
}
export -f iam-policy
