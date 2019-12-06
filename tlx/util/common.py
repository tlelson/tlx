import string
import random
from uuid import uuid4


def string_from_datetime(dt_obj, sep=None, timespec='milliseconds'):
    """string format from python datetime"""
    # Pandas datetime is not yet implimenting `timespec`
    # https://github.com/pandas-dev/pandas/issues/26131
    try:
        return dt_obj.isoformat(sep=sep, timespec=timespec)
    except TypeError as e:
        msg = ("\n\nATTN!! If your datetime is actually "
               "`pandas._libs.tslibs.timestamps.Timestamp`"
               " then you may raise this exception.  Use `to_pydatetime` "
               "to convert it.\n\n")
        print(msg)
        raise e


def get_dynamo_compatible_uuid():
    """ Returns a 32 char random hash garenteeing lowercase letter at the begining.
        (DynamoDB has issues with digits at the start)
    """
    return random.choice(string.ascii_lowercase) + uuid4().hex[1:]
