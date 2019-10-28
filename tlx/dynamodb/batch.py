import csv
import io
import math
import json
import boto3
from decimal import Decimal
from collections import defaultdict
from tlx.util import get_uuid


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


def batch_write(table, items):
    """
        Basic Usage:
        >>> from tlx.dynamodb.batch import batch_write, get_ddb_table
        >>> table = get_ddb_table('Table-Name')
        >>> with open('results-20180821-091839.json', 'r') as f:
        ...     items = json.load(f)
        >>> batch_write(table, items)
    """

    table = get_ddb_table(table)

    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(
                Item=item,
            )


def batch_delete(table, item_keys):
    """
        item_keys must be a list of dictionary of the keys required by the Table.
        e.g for a single key table: [{'id': 001, 'id': 002, ...}]
        for tables with a sort key, that must be included.
    """

    table = get_ddb_table(table)

    with table.batch_writer() as batch:
        for item_key in item_keys:
            batch.delete_item(Key=item_key)


def load_scan_dump(dump_file, table=None):
    """
        Loads the results of a scan opperation into a table.

        Details:
        Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>`
        and writes to an existing table. Similar to the `aws dynamodb batch-write-item` command except:
            - No limit to amount of items in the upload (25 with awscli)
            - Take the output of a table scan, requiring no reformatting
    """

    table = get_ddb_table(table)
    items = json.load(dump_file)['Items']
    # TODO: Make this a generator (problem is testing it)
    batch_write(table, [_pull_values(item) for item in items])


def load_from_csv(csv_file, table):
    """ CSV must conform to the following format:
            first row:  Field names
            second row: Field types. One of: ['N', 'S']

        N.B Only works for flat data structures. i.e Maps/Lists/Sets are not supported
    """

    table = get_ddb_table(table)

    with io.open(csv_file, newline='') as csvfile:
        data = list(csv.reader(csvfile))

    field_names, types = data[0], data[1]

    # Throws KeyError if missing. Only string and number are supported for csv
    def _format_number(x):
        tmp = Decimal(x if x else 'Nan')
        if math.isnan(tmp) or math.isinf(tmp):
            # Remove Inf and Nan, DynamoDB does support them
            return None
        return tmp

    _this_func_map = {
        'N': _format_number,
        'S': lambda x: str(x),
    }

    # Decimal Conversion if string field
    try:
        ddata = [  # Not a generator for testing
            {
                k1: v1
                for k1, v1 in (
                    (k, _this_func_map[t](v))
                    for k, t, v in zip(field_names, types, d)
                )
                if v1
            }
            for d in data[2:]
        ]
    except KeyError:
        raise Exception("load_from_csv only supports Dynamo Types {}".format(list(_this_func_map)))

    batch_write(table, ddata)


def load_json_dump(file_name, table_name, primary_key=False):
    """ Loads a file consisting of newline seperated items, in which each item is
        a json row object (Such as a BigQuery dump).

        If `primary_key` is provided the field is added to each item with a unique id as the sole partition key.
        If not provided, the input data must contain the keys of the dynamodb.
    """
    table = get_ddb_table(table_name)

    with open(file_name, 'r') as f:
        items = [
            json.loads(line.replace('\n', ''), parse_int=Decimal, parse_float=Decimal)
            for line in f
        ]

    if primary_key:
        for i in items:
            i[primary_key] = get_uuid()

    batch_write(table, items)


def get_ddb_table(table):
    """Takes either a string or an existing boto3 Table object.  If neither raises Exception"""

    try:  # test is boto3 Table object
        _ = table.name  # noqa: F841
    except AttributeError:
        if isinstance(table, str):
            dynamodb = boto3.resource('dynamodb')
            table = dynamodb.Table(table)
        else:
            raise Exception(("Table must be either a boto3 Table object"
                             "or a string not: {}").format(type(table)))
    return table
