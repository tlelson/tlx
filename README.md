# TLX

[![Build Status](https://travis-ci.org/eL0ck/tlx.svg?branch=master)](https://travis-ci.org/eL0ck/tlx)

Tools for working with AWS.

## Install

```bash
pip install tlx
```

## CLI apps
Tools that should be in the `awscli` but aren't or don't function well.  All have `--help` for details.

All CLI applications have their own detailed help menus.  Currently available tools are:

| function | description |
|---| --- |
| `get-aws-creds` | returns temporary session credentials. Locally mock AWS runtime environments, debugging IAM etc |
| `dynamo-batch-write` | loads scan results into a dynamo table.  Much better than `awscli` option |

```bash
$ dynamo-batch-write --help
Usage: dynamo-batch-write [OPTIONS]

  DYNAMO BATCH WRITE

  Loads the results of a scan opperation into a table.

  Details:
  Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>`
  and writes to an existing table. Similar to the `aws dynamodb batch-write-item` command except:
      - No limit to amount of items in the upload (25 with awscli)
      - Take the output of a table scan, requiring no reformatting

Options:
  -d, --dump-file FILENAME  File dumped from dynamodb with a `scan`.  [required]
  -t, --table TEXT          Table to send data to. Table must exist and key schema must match.  Use `aws dynamodb
                            describe-table --table-name <TableName>`  [required]
  -h, --help                Show this message and exit.
```


## Module Summary
Import these in a python program or shell.

| function | description |
|---| --- |
| `tlx.apigateway` | Reduce boilerplate when using proxy response lambdas with API Gateway |
| `tlx.dynamodb` | `clear_table`, batch loaders for csv bigquery and functions for nested data reliably |
| `tlx.util` | Extra tools such as: better boto3 `Session`, generic paginator that works on all boto3 calls + more |


*See Submodule docs for more examples.*
- [Utilities](tlx/util/README.md)
- [Api Gateway Module](tlx/apigateway/README.md)
- [Dynamodb Tools](tlx/dynamodb/README.md)

## Light install
If this grows too large it may become a namespace package so that individual parts can be installed easily. But until that time if you need a tool and only that tool, say for a deployment to AWS lambda or GCP App Engine, then:

1.  Do a local install without dependencies: `pip install --no-deps -t package/location/ tlx`
2.  Run your project and install the dependencies as you encounter import errors.
