import vcr
import boto3
from tlx.util import paginate


@vcr.use_cassette
def test_describe_log_groups():
    logs = boto3.client('logs', region_name='ap-southeast-2')

    page0 = logs.describe_log_groups()['logGroups']
    all_pages = [x for x in paginate(logs.describe_log_groups)]

    # Both return ordered lists
    assert page0 == all_pages[:len(page0)]
    assert len(page0) == 50
    assert len(all_pages) == 2131


@vcr.use_cassette
def test_list_stacks():
    cfn = boto3.client('cloudformation', region_name='ap-southeast-2')

    page0 = cfn.list_stacks()['StackSummaries']
    all_pages = [x for x in paginate(cfn.list_stacks)]

    # Both return ordered lists
    assert page0 == all_pages[:len(page0)]
    assert len(page0) == 100
    assert len(all_pages) == 1340


@vcr.use_cassette
def test_list_s3_objects():
    s3 = boto3.client('s3', region_name='ap-southeast-2')

    bucket_name = s3.list_buckets()['Buckets'][0]['Name']

    params = dict(Bucket=bucket_name, MaxKeys=10)

    page0 = s3.list_objects(**params)['Contents']
    all_pages = [x for x in paginate(s3.list_objects, **params)]

    # Both return ordered lists
    assert page0 == all_pages[:len(page0)]
    assert len(page0) == 10
    assert len(all_pages) == 15
