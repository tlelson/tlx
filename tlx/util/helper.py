def paginate(method, **kwargs):
    """ Automatically paginates through result lists regardless of what type of marker/token/continuation
        AWS decided to use on that service. Will raise `OperationNotPageableError` if the operation is
        not pagable.

        e.g Get all Log groups rather than just the first 50
            >>> log_groups = [lg['logGroupName'] for lg in paginate(logs.describe_log_groups)]  # `nextToken`
            >>> all_resources = [ r for r in paginate(apig.get_resources, restApiId=rest_apis[0]['id']]  # `position`
            >>> all_stacks = [ s for s in paginate(cfn.list_stacks)]  # `NextToken`
            >>> all_roles = [r for r in paginate(iam.list_roles)]  # `Marker`
            >>> all_objects = [ob for ob in paginate(s3.list_objects, Bucket=bucket_name, MaxKeys=10)]
    """

    client = method.__self__
    paginator = client.get_paginator(method.__name__)
    for page in paginator.paginate(**kwargs).result_key_iters():
        try:
            for result in page:
                yield result
        except TypeError:
            pass
