# APIGateway Modules

This module provides functions to make python for AWS lambda more idiomatic.

## Function Summary

See docstring for detailed usage.

| function | description |
|---| --- |
| `proxy_response_handler` | Use API Gateway 'Proxy Response' but raise exceptions as you should |
| `require_valid_inputs` | Compare supplied params against required ones and return 400 if necessary |
| `APIGException` | An exception class to raise when using `proxy_response_handler` |

## Examples

Use the `proxy_response_handler` to ensure that all exceptions are handled and returned to the caller as 500 (rather than the ambiguous default).
```python
from tlx.apigateway import proxy_response_handler

@proxy_response_handler
def lambda_handler(event, context):

    # If any exceptions occur at all in this scope
    # a 500 response is returned.
    resource, params = event['resource'], event['queryStringParameters']
    data = json.loads(event['body'])

    return get_user(params['id'])
```

Suppose you want to return a specific error code and message; raise an `APIGException`.
```python
from tlx.apigateway import proxy_response_handler, APIGException


@proxy_response_handler
def lambda_handler(event, context):
    try:
        resource, params = event['resource'], event['queryStringParameters']
        data = json.loads(event['body'])

        return get_user(params['id'])
    except KeyError:
        raise APIGException('Missing keys', code=400)

```

There is a function that abstracts away input parameter checking and raises a `APIGException` for you.
In this case use the `require_valid_inputs` function.
and return a meaningful error message to the user.
```python
from tlx.apigateway import proxy_response_handler, require_valid_inputs


@proxy_response_handler
def lambda_handler(event, context):
    resource, params = event['resource'], event['queryStringParameters']

    require_valid_inputs(params, {'id'})
    return get_user(params['id'])
```
