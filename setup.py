from setuptools import setup, find_packages
import os

here = os.path.dirname(os.path.realpath(__file__))


def get_install_requires():
    with open(os.path.join(here, 'requirements.txt'), 'r') as f:
        return f.read().splitlines()


def get_version():
    with open(os.path.join(here, 'version.txt'), 'r') as f:
        return f.readline().split()[0]  # Filter out other junk


setup(
    name='tlx',
    version=get_version(),
    description='Frequently used utilities and code.',
    url='https://github.com/eL0ck/tlx',
    author='eL0ck',
    author_email='tpj800@gmail.com',
    license='Apache',
    python_requires='>=3.6, <4',
    packages=find_packages(),
    install_requires=get_install_requires(),
    entry_points={
        'console_scripts': [
            'get-aws-creds=tlx.util.cli_apps.get_aws_creds:main',
            'dynamo-batch-write=tlx.dynamodb.cli_apps.dynamodb_batch_write:dbw',
            'dynamo-clear-table=tlx.dynamodb.cli_apps.dynamodb_clear_table:dct',
        ],
    },
    scripts=[
        "tools/codebuild-logs",
        "tools/aws-list-accounts",
        "tools/pipeline-check",
        "tools/pipeline-status",
        "tools/stack-delete",
        "tools/stack-events",
        "tools/stack-status",
        "tools/lambda-logs",
        "tools/cfn-list-all-stack-resources",
    ],
    data_files=[
        'version.txt',
        'requirements.txt',
    ],
    zip_safe=False,
)
