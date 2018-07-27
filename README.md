# TLX

Often needed utilities and code.

This is a namespace package.  Submodules sometimes share dependencies but are often used/deployed in to production seperately.

## Examples

### Session
Use a session to start a session using a profile from `~/.aws/credentials` that is renewable without closing the shell.
```
from tlx.util import Session
session = Session(profile='Trades')
logs = session.client('logs')
[lg['logGroupName'] for lg in logs.describe_log_groups()['logGroups']]
```

*See Submodule docs for more examples.*
[Api Gateway Module](tlx/apigateway/README.md)


### Batch Upload data to Dynamodb
```
from tlx.dynamodb.batch import load_from_csv

# f = 'Probs_mine.csv'
f = 'Probs_sml.csv'
tbl_name = 'USRacingStacks-bet-dev-Probs'
load_from_csv(f, tbl_name)
```

## Light install
If this grows too large it may become a namespace packge so that parts can be installed easily. But until that time if you need a tool and only that tool, say for a deployment to AWS lambda or GCP App engine, then:

1.  Do a local install without dependencies:
`pip install --no-deps -t package/location/ tlx`
2.  Remove all the things you dont need
3.  Run your project and install the dependencies as above until it works.


