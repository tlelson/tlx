# Dynamodb Tools

This module provides python tools to take out some of the boilerplate when operating with Dynamodb. Some of the python tools have a CLI interface.

## Examples

### Batch Upload data to Dynamodb

There are certain limitations with each of the load functions that are explained in the docstrings or help menus.

```python
from tlx.dynamodb.batch import load_from_csv
#load_from_csv?  # Show docstring

f = 'Probs.csv'
tbl_name = 'Probs-Tables'
load_from_csv(f, tbl_name)
```

## CLI aplications

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
