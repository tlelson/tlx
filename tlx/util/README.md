# General Utilities

A collection of base tools.

## Examples

### Session
This can be used to start a session with the Aws REST APIs.

```
from tlx.util import Session
session = Session()                             # Using [default] profile
logs = session.client('logs')                   # Equiv to boto3.client('logs')

[lg['logGroupName'] for lg in logs.describe_log_groups()['logGroups']]
```

Frequently we are required to assume roles which provide temporary authentication
tokens. These temporary tokens can be generated and exported to your working shell
using `get-aws-creds --profile <ProfileName>` but this requires loosing your work
inside the python shell.

An alternative is to create and renew the session inside the shell.

```
session = Session(
    role='arn:aws:iam::906000109495:role/Trades',
    mfa_serial='arn:aws:iam::805000357058:mfa/IAM-F.Last',
    mfa_token='438660',
)
```
Or, if the role is configured in `.aws/credentials`:
```
session = Session(profile='Trades')             # Using [Trades] profile

```


