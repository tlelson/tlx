#!/usr/bin/env python

from __future__ import print_function
import click
import os
import sys
from tlx.util import Session


@click.command(context_settings=dict(max_content_width=120))
@click.option('--profile', '-p', default='default', help="A profile defined in `~/.aws/credentials`.  If it requires an MFA token a prompt will be given")
@click.option('--quiet', default=False, is_flag=True, help='If using the outputs directly, see --help.')
def main(profile, quiet):
    """
        GET AWS CREDS (GAC):

        Gets temporary AWS session from a profile (user or role).  Allows you to export into your shell and run tools expecting the AWS standard environment variables. Namely:

        \b
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - AWS_SESSION_TOKEN

        Your aws credentials file (default: `~/.aws/credentials`) should be configured as follows:

        A Role profile would look like:

        \b
            [roleprofilename]
            region = us-east-2
            role_arn = arn:aws:iam::************:role/<IAM_Role_name>
            mfa_serial = arn:aws:iam::<AccountID>:mfa/<IAM_user_name>
            source_profile = default

        Or a user profile might look like:

        \b
            [userprofilename]
            aws_access_key_id =  AKIA****************
            aws_secret_access_key = gMFRKAaeFM0*****************************
            mfa_serial = arn:aws:iam::<AccountID>:mfa/<IAM_user_name>
            region = ap-southeast-2

        Notice that the user profile contains `mfa_serial`.  This is not standard aws config however it is supported by GAC.  If it is available, GAC will use it to get temporary session tokens by requesting your associated MFA code.  This is useful for when your user has higher account priviledges that require MFA auth.


        Returns: commands to copy to your shell terminal

        -------------------------- ADVANCED USAGE --------------------------------------

        Consider appending the following to your `.bashrc` to have the environment variables set automatically:

        \b
            gac ()
            {
                for i in "$( get-aws-creds "$@" --quiet)";
                do
                    eval "${i}";
                done
            }


        Or alternatively, send the variables to a file and source them from your profile so that all terminal sessions receive the same temporary credentials:

            \b
            $ get-aws-creds --quiet > /tmp/awscreds
            $ source /tmp/awscreds
    """

    # Issue #15 - We may be trying to assume another role from a
    # shell that has previously had its temporyary variables populated
    if 'AWS_SECRET_ACCESS_KEY' in os.environ:
        del os.environ['AWS_SECRET_ACCESS_KEY']
    if 'AWS_ACCESS_KEY_ID' in os.environ:
        del os.environ['AWS_ACCESS_KEY_ID']

    try:
        session = Session(profile=profile)
        creds = session.get_session_creds()
    except Exception as e:
        print("{}: {}".format(type(e).__name__, e))
        sys.exit(1)

    if not quiet:
        print("Keys and token for profile: '{profile}'".format(profile=profile))
        print("Paste the following into your shell:\n")

    print("export AWS_ACCESS_KEY_ID={}".format(creds.access_key))
    print("export AWS_SECRET_ACCESS_KEY={}".format(creds.secret_key))
    print("export AWS_SESSION_TOKEN={}".format(creds.token))  # We always return temp creds now
