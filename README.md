# TLX

Tools for working with AWS.

## Install

This package is not distributed through pypi.  Clone the repository and install it locally.

```bash
pip install -e .
```

## CLI apps

Tools that should be in the `awscli` but aren't or don't function well.  All have `--help` for details.

All CLI applications have their own detailed help menus.  Currently available tools are:

| function | description |
|---| --- |
| `get-aws-creds` | returns temporary session credentials. Locally mock AWS runtime environments, debugging IAM etc |
| `dynamo-batch-write` | loads scan results into a dynamo table.  Much better than `awscli` option |
| `dynamo-clear-table` | empties the items from a dynamodb table |

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

## AWS CLI Wrappers

A collection of tools and alias' that make remembering aws cli commands easier and faster.

They are not production grade.

### Standard features

1. They start with the name of the service so that you can hit tab and see the options you expect. E.g: `code-pipeline` or `ecs`. Some may have a short alias such as `cp-` for `code-pipeline` because this is meant to make the aws cli more intuitive.  The command you want, should be guessable.

2. If the usage isn't obvious (e.g `ecs-clusters` ) then they have a `--help` with an example.

3. They produce json output. This allows standard tools like `jq` or `jtbl` to format it. The `--help` says what kind of output is produced. Lists of things should produce `jsonlines` so that the output can be grep'ed and still passed to `jtbl`. E.g `stack-status | grep meta | jtbl`

### Instalation

It is a manual step to source `./tools/rcfile` because you may choose to run it in a sub-shell to avoid polluting your environment.  For example I add the following alias to my .bashrc.

```bash
alias awsenv='bash --rcfile ${TLXPATH}/tools/rcfile'
```

Otherwise source the `.tools/rcfile` in your own way.

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
