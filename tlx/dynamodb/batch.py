import json
from decimal import Decimal
from collections import defaultdict


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


def load_data(scan_dump_file, table):
    """
        Loads the results of a scan opperation into a table.
    """
    with open(scan_dump_file, 'r') as f:
        scan_dump = json.load(f)

    with table.batch_writer() as batch:
        for item in scan_dump['Items']:
            batch.put_item(
                Item=_pull_values(item),
            )
