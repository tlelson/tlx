import json
import boto3
from decimal import Decimal
from collections import defaultdict


ddbclient = boto3.client('dynamodb')  # For exeption handling


def _pull_values(item):
    return {k: _set_types(v) for k, v in item.items()}


_func_map = defaultdict(
    lambda: lambda x: x, {
        'M': _pull_values,
        'N': Decimal,
        'L': lambda values: [_set_types(d) for d in values]
    }
)


def _set_types(v):
    v_key = list(v.keys())[0]
    returned_value = list(v.values())[0]  # Always one from dump
    return _func_map[v_key](returned_value)


def batch_delete(table, keys):
    with table.batch_writer() as batch:
        for key in keys:
            batch.delete_items(
                Key=key,
            )


def batch_write(table, items):
    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(
                Item=_pull_values(item),
            )


def load_data(dump_file, table=None):
    """
        Loads the results of a scan opperation into a table.

        Details:
        Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>`
        and writes to an existing table. Similar to the `aws dynamodb batch-write-item` command except:
            - No limit to amount of items in the upload (25 with awscli)
            - Take the output of a table scan, requiring no reformatting
    """

    if isinstance(table, str):
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table)
    elif isinstance(table, boto3.resources.factory.dynamodb.Table):
        pass
    else:
        raise Exception("table must be either the name of an existing table or a boto3 table object")

    items = json.load(dump_file)['Items']
    batch_write(table, items)
