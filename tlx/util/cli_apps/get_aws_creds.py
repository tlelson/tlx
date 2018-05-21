#!/usr/bin/env python

from __future__ import print_function
import click
import sys
from tlx.util import Session


@click.command(context_settings=dict(max_content_width=120))
@click.option('--profile', '-p', default='default', help="A profile defined in `~/.aws/credentials`.  If it requires an MFA token a prompt will be given")
@click.option('--quiet', default=False, is_flag=True, help='If using the outputs directly, see --help.')
def main(profile, quiet):
    """
        GET AWS CREDS (gac):

        Gets temporary AWS session from a profile.  Allows you to export into your shell and run tools expecting the AWS standard environment variables. Namely:

        \b
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - AWS_SESSION_TOKEN

        Your aws credentials file (default: `~/.aws/credentials`) should be configured like so:
        \b
        Configure `credentials` like so:

        \b
            [profilename]
            region = us-east-2
            role_arn = arn:aws:iam::************:role/Demo-StackCreator
            mfa_serial = arn:aws:iam::************:mfa/IAM-F.Name
            source_profile = default

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
    """

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
    print("export AWS_SESSION_TOKEN={}".format(creds.token))
