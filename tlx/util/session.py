import boto3
import logging
from botocore.credentials import DeferredRefreshableCredentials
from botocore.exceptions import ClientError


class Session(boto3.session.Session):
    """Returns an AWS session instance.  If no parameters are provided, keys from `.aws/credentials` 'default' profile are used.

        Kwargs (all optional):
            region (str): An AWS region
            profile (str): A profile with API keys as configured in ~/.aws/credentials file. Not to be used with other parmeters.
                If your role needs an MFA token you will be prompted for input.
            role (str): AWS Arn of the role the user is assuming. If None, the users identity is used.
            mfa_serial (str): AWS Arn of the users Multi-Factor authentication device.
            mfa_token (str): 6 digit Multi-Factor Authentication code.

        Example:
            session = Session()
            s3client = session.client('s3')
    """

    def __init__(self, region=None, profile=None, role=None, mfa_serial=None, mfa_token=None):
        if profile and role:
            raise AttributeError("Either a profile should be used OR a role assumed. Not both.")

        if (mfa_serial and not mfa_token) or (mfa_token and not mfa_serial):
            raise AttributeError("If using MFA, provide both a serial and a token.")

        params = {
            'region_name': region,
        }

        if role:
            creds = _assume_role(role, mfa_serial, mfa_token)
            params.update({
                'aws_access_key_id': creds['AccessKeyId'],
                'aws_secret_access_key': creds['SecretAccessKey'],
                'aws_session_token': creds['SessionToken'],
            })
        elif profile:
            params['profile_name'] = profile
        try:
            boto3.session.Session.__init__(self, **{k: v for k, v in params.items() if v})
        except ClientError as e:
            logging.error("Do the API keys in `~/.aws/credentials` match those required? \n{}".format(e))

    def get_session_creds(self):
        creds = self.get_credentials()

        if isinstance(creds, DeferredRefreshableCredentials):
            # prompt for MFA token
            creds = creds.get_frozen_credentials()

        return creds


def _assume_role(role, mfa_serial, mfa_token):
    # TODO: Check for HTTP fail
    params = {
        "RoleArn": role,
        "RoleSessionName": 'ecs-deploy-session',
        "DurationSeconds": 3600 * 8,  # Try 8 hours
        "SerialNumber": mfa_serial,
        "TokenCode": mfa_token
    }
    return boto3.client('sts').assume_role(**{k: v for k, v in params.items() if v})['Credentials']
