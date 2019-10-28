import sys
import logging
from tlx.dynamodb.batch import batch_delete, get_ddb_table
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Bellow thows a syntax error in python 2.7. no idea why
# py_version = float(f"{sys.version_info.major}.{sys.version_info.minor}")
py_version = float("{}.{}".format(sys.version_info.major, sys.version_info.minor))

if py_version < 3.6:
    raise RuntimeError("This module is not for python <3.6.")


def add_key(table, key, item):
    """ If the item doesn't exist yet. Create the key.
        !! Does NOT support tables with Partition and Sort keys Yet.
    """

    key_names = [k for k in key]
    full_item = {**key, **item}  # noqa: E999   - only invalid in old pythons
    logger.debug(f'submitting item: {full_item}')  # noqa: E999   - only invalid in old pythons

    logger.info(f"Attempting to add new record for: {key} ")
    res = table.put_item(
        Item=full_item,
        ConditionExpression=f"attribute_not_exists({key_names[0]})",  # TODO fix for items with Partition and Sort key
    )

    logger.info(f"Successfully added new record.")
    logger.debug(f"{full_item}")
    return res['ResponseMetadata']['HTTPStatusCode']


def append_to_list_field(table, key, field_to_update, expression_attribute_names, new_item, add_missing_key=False):
    """ Appends `new_item` to existing item `field_to_update` for a given `key`.

        N.B. If the field is not found, attempts are made to create the entire path of `field_to_update`.
        If the key is not found, attempt to create it.

        Args:
            table (boto3 Table):
            key (dict): Primary key for the table. e.g {'matchid': matchid}
            field_to_update (list): e.g ['providers', '#dataproviderid'].  Variables for substitution should
                                    start with a hash and have values defined in `expression_attribute_names`.
            expression_attribute_names (dict): Expansion of variables names in the field to update.
                                               E.g {'#dataproviderid': "BILL"}
            new_item (list): To be appended to a list, the object must be a list.
            add_missing_key (bool): Default False. If True add the primary key for the table if it is not found.
                                    Otherwise returns dict of data to be added by user.

         Returns:
            int (200)                   - If successfully added item to Dynamodb
            dict {unadded data}         - If the primary key was not found. use `add_key` to add it.
    """
    try:
        str_path = '.'.join(field_to_update)
        # TODO: Consider adding a check for if key exists here rather than in the `_add_new_map_field` call stack
        # Current model is optimised for frequent updates of existing keys.  If keys are frequently being added
        # it would be more efficient to try adding the key first and then this method.
        res = table.update_item(
            Key=key,
            UpdateExpression=f"SET {str_path} = list_append(:new_item, {str_path})",
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues={":new_item": new_item},
            ConditionExpression=f"attribute_exists({str_path})",
        )
        logger.info(f"Successfully added new odds to: {str_path}")
        logger.debug(f'{new_item}')
        return res['ResponseMetadata']['HTTPStatusCode']
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        # Table missing some amount of structure
        logger.info(f"field not found: {str_path}")

    return add_new_map_field(table, key, field_to_update[:-1], field_to_update[-1], expression_attribute_names, new_item, add_missing_key)


def add_new_map_field(table, key, path, field_to_add, expression_attribute_names, data, add_missing_key=False, replace_existing=False):
    """ Adds a new field (field_to_add) to an existing path in a map (path) for a given Primary key (key).

        N.B If the path doesn't exist, the function attempts to create that path.  If the key doesn't exist,
        it will attempt to create IFF `add_missing_key=True`.

        Args:
            table (boto3 Table):
            key (dict): Must match the schema for `table`,
            path (list): List of field name strings in the map path. Use # if the field should be substitued for a value.
                         Specify that value in `expression_attribute_names`. E.g ['root', '#firstkey', '2ndkey']
            field_to_add (string): The name of the new field to add at the end of existing map described by `path`.
            expression_attribute_names (dict): Substitutes for the #values in `path`. E.g {'#firstkey': 'TeamMembers'}
            data (any): Value to be saved under `path`+`field_to_add`.  Must be valid datatypes for Dynamodb.
            add_missing_key (bool): Default False. If True add the primary key for the table if it is not found.
                                    Otherwise returns dict of data to be added by user.
            replace_existing (bool): Default False. If True, the `field_to_add` may exist already.  In the case that
                                     it does, it is replaced with `data`. If False, an error will be returned.
         Returns:
            int (200)                   - If successfully added item to Dynamodb
            dict {unadded data}         - If the primary key was not found. use `add_key` to add it.
    """

    if not path:  # Limit of recursion (Primary key was not found)
        return add_key(table, key, field_to_add, data) if add_missing_key else {field_to_add: data}

    str_path = '.'.join(path)
    # Default to error instead of overwrite
    condition_exp = f"attribute_not_exists({str_path}.{field_to_add}) AND attribute_exists({str_path})"
    if replace_existing:
        condition_exp = f"attribute_exists({str_path})"

    try:
        res = table.update_item(
            Key=key,
            UpdateExpression=f"SET {str_path}.{field_to_add} = :new_item",  # want dots to expand
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues={":new_item": data},
            ConditionExpression=condition_exp,
        )
        logger.info(f"Successfully added new data to: {str_path}.{field_to_add}")
        logger.debug(f'{data}')
        return res['ResponseMetadata']['HTTPStatusCode']
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        logger.info(f"Path ({str_path}) not found.")
    except table.meta.client.exceptions.ClientError as ce:
        # The document path has changed. Allow it to overwrite next itteration otherwise raise
        if ce.response['Error']['Code'] in ('ValidationException',):
            msg = "The document path has changed. Overwriting existing data!"
            logger.warn(msg)
            replace_existing = True
        else:
            raise ce

    # Must remove otherwise boto complains 'unused in expressions' next time
    new_data = {expression_attribute_names.pop(field_to_add, field_to_add): data}

    # Recursively try to add until we empty the 'path' variable
    return add_new_map_field(table, key, path[:-1], path[-1], expression_attribute_names, new_data, replace_existing=replace_existing)


def clear_table(table):
    """NOT TESTED with Primary and Sort Key Tables !!!
        TODO:
            - test on multikey tables
            - make cli app for it
    """

    table = get_ddb_table(table)

    table_keys = [key['AttributeName'] for key in table.key_schema]
    all_ids = ({key: r[key] for key in table_keys} for r in table.scan()['Items'])
    batch_delete(table, all_ids)
