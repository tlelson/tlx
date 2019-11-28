# Dynamodb Tools

This module provides python tools to take out some boilerplate when operating with Dynamodb.

Some of the python functions have a CLI interface.

## CLI aplications
As always, use the `--help` flag to get started

- `dynamo-batch-write`

## Function Summary

See doc string for detailed usage.


| function | description |
|---| --- |
| `batch_delete` | Efficiently deletes all specified items in a provided table name |
| `batch_write` | Efficiently write items to a provided table name |
| `get_ddb_table` | Get boot table object by name. Can be used as a check since takes and returns table object too |
| `load_from_csv` | Loads csv data file.  See docstring for details |
| `load_json_dump` | Loads a 'jsonlines' file such as a BigQuery dump |
| `load_scan_dump` | Loads the results of a scan opperation into a table |


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

