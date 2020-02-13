import os
import boto3
import logging
from getpass import getpass
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


        NB: If you already have AWS environment variables in the root shell they will take precedence. Override them by specifing any arguments.
    """

    def __init__(self, profile=None, region=None, role=None, mfa_serial=None, mfa_token=None):
        if profile and role:
            raise AttributeError("Either a profile should be used OR a role assumed. Not both.")

        params = {
            'region_name': region,
        }

        # 1. Allow pass through if env vars already exist - Dont need extra params boto will get them
        temp_creds_already_exist = len(
            {'AWS_SECRET_ACCESS_KEY', 'AWS_ACCESS_KEY_ID', 'AWS_SESSION_TOKEN'}.intersection(os.environ)
        ) == 3
        if temp_creds_already_exist:
            pass  # this is all we need  TODO: test on expired ones

        # 2. If assuming a role get temp creds
        if role:  # ! Not `elif` because role should override
            creds = _assume_role(role, mfa_serial, mfa_token)
            params.update({
                'aws_access_key_id': creds['AccessKeyId'],
                'aws_secret_access_key': creds['SecretAccessKey'],
                'aws_session_token': creds['SessionToken'],
            })
        # 4. If pofile is user profile and has mfa, populate env var params like role
        profile_mfa_serial = _get_mfa_serial_if_user(profile) if profile and not temp_creds_already_exist else None
        if profile_mfa_serial:
            if not mfa_token:
                mfa_token = getpass(f'Enter MFA code for {profile_mfa_serial}: ')

            user_base_session = boto3.session.Session(profile_name=profile)
            creds = user_base_session.client('sts').get_session_token(
                SerialNumber=profile_mfa_serial,
                TokenCode=mfa_token,
            )['Credentials']
            params.update({
                'aws_access_key_id': creds['AccessKeyId'],
                'aws_secret_access_key': creds['SecretAccessKey'],
                'aws_session_token': creds['SessionToken'],
            })

        # 3. If profile add it to input params
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


def _get_mfa_serial_if_user(profile):
    """Finds users mfa_serial from ~/.aws/credentials"""

    profile = profile or 'default'
    correct_profile = False
    is_user_profile = None  # Should return None if Role profile
    identified_mfa_serial = None

    with open(os.path.expanduser('~/.aws/credentials'), 'r') as f:
        for line in f:
            if line.startswith(f"[{profile}]"):
                correct_profile = True
            elif correct_profile and line.startswith('mfa_serial'):
                identified_mfa_serial = line.split('=')[-1].strip()
            elif correct_profile and line.startswith('aws_access_key_id'):
                is_user_profile = True
            elif line == '\n':
                if correct_profile:
                    break  # No need to search futher

    if not correct_profile:
        msg = f"Profile '{profile}' not found.  Typo?"
        raise Exception(msg)

    if is_user_profile:
        return identified_mfa_serial
    # Otherwise we have found a Role or other that will automatically pick
    # up the MFA by boto
    return None


def _assume_role(role, mfa_serial, mfa_token):
    params = {
        "RoleArn": role,
        "RoleSessionName": role,
        "SerialNumber": mfa_serial,
        "TokenCode": mfa_token
    }
    return boto3.client('sts').assume_role(**{k: v for k, v in params.items() if v})['Credentials']
