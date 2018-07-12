def paginate(method, **kwargs):
    """ Automatically paginates through result lists that yeild a 'nextToken' field
        e.g Get all Log groups rather than just the first 50
            >>> [lg['logGroupName'] for lg in paginate(logs.describe_log_groups)]
    """

    client = method.__self__
    paginator = client.get_paginator(method.__name__)
    for page in paginator.paginate(**kwargs).result_key_iters():
        for result in page:
            yield result
