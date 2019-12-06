# Dynamodb Tools

This module provides python tools to reduce boilerplate when operating with DynamoDB.

Some of the python functions have a CLI interface.

## CLI aplications
As always, use the `--help` flag to get started

- `dynamo-batch-write`

## Function Summary

See docstring for detailed usage.

| function | description |
|---| --- |
| `batch_delete` | Efficiently deletes all specified items in a provided table name |
| `batch_write` | Efficiently write items to a provided table name |
| `get_ddb_table` | Get boto3 table object by name. Can be used as a check since takes and returns table object |
| `load_from_csv` | Loads csv data file.  See docstring for details |
| `load_json_dump` | Loads a _jsonlines_ file such as a BigQuery dump |
| `load_scan_dump` | Loads the results of a scan opperation into a table. *This is not possible with boto3!* |
| `json_loads` | like `json.loads` but prepares Decimals and Timestamps for Dynamo |
| `json_dumps` | like `json.dumps` but handles Decimals and converts Timestamps to ISO format |


## Examples

### Batch Upload data to DynamoDB

There are certain limitations with each of the load functions that are explained in the docstrings or help menus.

```python
from tlx.dynamodb.batch import load_from_csv
#load_from_csv?  # Show docstring

f = 'Probs.csv'
tbl_name = 'Probs-Tables'
load_from_csv(f, tbl_name)
```

