# TLX

Often needed utilities and code.

This is a namespace package.  Submodules sometimes share dependencies but are often used/deployed in to production seperately.

## CLI apps

All CLI applications have their own detailed help menus.  Currently available tools are:

- `get-aws-creds`
- `dynamo-batch-prepare`
- `dynamo-batch-write`

```bash
$ dynamo-batch-prepare --help
Usage: dynamo-batch-prepare [OPTIONS]

  DYNAMO BATCH PREPARE (dbp)

  `dynamodb-batch-prepare --help`
  OR
  `dbp --help`

  Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>` and formats for use
  by:

  `aws dynamodb batch-write-item --request-items file://output.json`

Options:
  -d, --dump-file FILENAME  File dumped from dynamodb with.  [required]
  -n, --table-name TEXT     Table to send data to. Table must exist and key schema must match.  Use `aws dynamodb
                            describe-table --table-name <TableName>`  [required]
  -h, --help                Show this message and exit.
```

## Examples
*See Submodule docs for more examples.*
- [Utilities](tlx/util/README.md)
- [Api Gateway Module](tlx/apigateway/README.md)
- [Dynamodb Tools](tlx/dynamodb/README.md)

## Light install
If this grows too large it may become a namespace packge so that parts can be installed easily. But until that time if you need a tool and only that tool, say for a deployment to AWS lambda or GCP App engine, then:

1.  Do a local install without dependencies:
`pip install --no-deps -t package/location/ tlx`
2.  Remove all the things you dont need
3.  Run your project and install the dependencies as above until it works.

