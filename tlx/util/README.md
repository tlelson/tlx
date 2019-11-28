# General Utilities

A collection of base tools.

## Function Summary

See docstring for detailed usage.

`import tlx.util`

| function | description |
|---| --- |
| `string_from_datetime` | Stringify a datetime object |
| `get_ddb_compatible_uuid` | Get a 32 char hex UUID that doesn't|
| `paginate` | Easy get all items from a pagable boto3 call |
| `Session` | Extends boto3 `Session`.  Provides extra features such as temp tokens for users requiring mfa |
| `ensure_http_success` | Decorate function that makes an boto3 API call.  Avoid boilerplate of checking `HTTPStatusCode` every time. |

## Examples
### Session
This can be used to start a session with the AWS REST APIs.

```python
from tlx.util import Session
session = Session()                             # Using [default] profile
logs = session.client('logs')                   # Equiv to boto3.client('logs')

[lg['logGroupName'] for lg in logs.describe_log_groups()['logGroups']]
```

Frequently we are required to assume roles which then provide temporary authentication
tokens. These temporary tokens can be generated and exported to your working shell
using the `get-aws-creds --profile <ProfileName>` CLI utility. The drawback is that
this requires you to exit your python shell to renew a token, thus loosing all your
work inside the python shell.

An alternative is to create and renew the session inside the shell.

```python
session = Session(
    role='arn:aws:iam::906000109495:role/Developer',
    mfa_serial='arn:aws:iam::906000109495:mfa/IAM-F.Last',
    mfa_token='438660',
)
```
Or, if the role is configured in `.aws/credentials`:
```python
session = Session(profile='Developer')             # Using [Trades] profile
```

