# flake8: noqa F401         - import not used error
from .table import add_key, append_to_list_field, add_new_map_field, clear_table, full_scan
from .aux import json_loads, json_dumps, DynamoEncoder
from .batch import batch_write, batch_delete, load_scan_dump, load_json_dump, get_ddb_table

name = 'dynamodb'
