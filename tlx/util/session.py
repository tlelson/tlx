import os
import boto3
import logging
from botocore.credentials import DeferredRefreshableCredentials
from botocore.exceptions import ClientError


class Session(boto3.session.Session):
    """Returns an AWS session instance.  If no parameters are provided, keys from `.aws/credentials` 'default' profile are used.

        Kwargs (all optional):
            profile (str): A profile with API keys as configured in ~/.aws/credentials file. Not to be used with other parmeters.
                If your role needs an MFA token you will be prompted for input.
            region (str): An AWS region
            role (str): AWS Arn of the role the user is assuming. If None, the users identity is used.
            mfa_serial (str): AWS Arn of the users Multi-Factor authentication device.
            mfa_token (str): 6 digit Multi-Factor Authentication code.

        Example:
            session = Session()
            s3client = session.client('s3')
    """

    def __init__(self, profile=None, region=None, role=None, mfa_serial=None, mfa_token=None):
        if profile and role:
            raise AttributeError("Either a profile should be used OR a role assumed. Not both.")

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

        # Get temp session even if running default (to force use of MFA)
        profile_mfa_serial = get_mfa_serial(profile)

        if profile_mfa_serial:
            if not mfa_token:
                mfa_token = input(f"Enter the MFA Token for {profile_mfa_serial}: ")
            creds = boto3.client('sts').get_session_token(
                SerialNumber=profile_mfa_serial,
                TokenCode=mfa_token,
            )['Credentials']
            params.update({
                'aws_access_key_id': creds['AccessKeyId'],
                'aws_secret_access_key': creds['SecretAccessKey'],
                'aws_session_token': creds['SessionToken'],
            })
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


def get_mfa_serial(profile):
    """Finds users mfa_serial from ~/.aws/credentials"""

    profile = profile or 'default'
    correct_profile = False

    with open(os.path.expanduser('~/.aws/credentials'), 'r') as f:
        for line in f:
            if line.startswith(f"[{profile}]"):
                correct_profile = True
            elif correct_profile and line.startswith('mfa_serial'):
                return line.split('=')[-1].strip()
            elif line == '\n':
                if correct_profile:
                    return None  # This profile doesn't have mfa_serial
        else:
            msg = f"Profile '{profile}' not found.  Typo?"
            raise Exception(msg)


def _assume_role(role, mfa_serial, mfa_token):
    # TODO: Check for HTTP fail
    params = {
        "RoleArn": role,
        "RoleSessionName": 'ecs-deploy-session',
        # "DurationSeconds": 3600, * 8,  # Try 8 hours
        "SerialNumber": mfa_serial,
        "TokenCode": mfa_token
    }
    return boto3.client('sts').assume_role(**{k: v for k, v in params.items() if v})['Credentials']
