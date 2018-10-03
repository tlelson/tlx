# Dynamodb Tools

This module provides python tools to take out some boilerplate when operating with Dynamodb.

Some of the python functions have a CLI interface.

## CLI aplications
As always, use the `--help` flag to get started

- `dynamo-batch-write`

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

