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

## Hacky CLI Tools

A collection of tools and alias' that make remembering aws cli commands easier and faster.

They are not production grade.

It is a manual step to source `./tools/rcfile` because you may choose to run it in a sub-shell to avoid polluting your environment.  For example I add the following alias to my .bashrc.
```bash
alias awsenv='bash --rcfile ${TLXPATH}/tools/rcfile'
```
Otherwise source the `.tools/alias` in your own way.

Most have an example usages if no args are given. e.g

```bash
$ cp-status --help
Usage: cp-status [OPTIONAL_ARGS] [options]

        Optional Arguments:
        pipeline_name_filter    grep regex to filter pipelines

        Options:
        --help                  Display this help message
```

- `aws-list-accounts`: list the accounts in your `.aws/config`
- `cp-state`: current state of a code-pipeline
- `cp-status`: status of all code-pipelines with optional arg to filter name
- `stack-status`: lists all cloudformation stacks and their status. Provide filter expression to reduce the output.
- `stack-delete`: delete a stack using the cloudformation command.
- `stack-delete-force`: aggressively delete a stack. Be careful. This will delete non-empty buckets. Non-empty ECR repos and remove log groups regardless of their retention policies.
- `stack-events`: defaults to last 10 but provide a number to go back more/less
- `cfn-resources`: list all resources deployed by cloudformation in any stack.


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
