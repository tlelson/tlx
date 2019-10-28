import string
import random
from uuid import uuid4


def _stringify(d):
    """Returns a ISO 8601 string from a datetime object. """
    return d.replace(tzinfo=None).isoformat(' ', timespec='milliseconds')


def get_uuid():
    """Returns a 32 char random hash garenteeing lowercase letter at the begining"""
    return uuid4().hex


def string_from_datetime(dt_obj, sep=None, timespec='milliseconds'):
    """string format from python datetime"""
    # Pandas datetime is not yet implimenting `timespec`
    # https://github.com/pandas-dev/pandas/issues/26131
    try:
        return dt_obj.replace(tzinfo=None).isoformat(sep=sep, timespec=timespec)
    except TypeError as e:
        msg = ("\n\nATTN!! If your datetime is actually "
               "`pandas._libs.tslibs.timestamps.Timestamp`"
               " then you may raise this exception.  Use `to_pydatetime` "
               "to convert it.\n\n")
        print(msg)
        raise e


def get_random_eventid():
    """ Returns a 32 char random hash garenteeing lowercase letter at the begining.
        (DynamoDB has issues with digits at the start)
    """
    return random.choice(string.ascii_lowercase) + uuid4().hex[1:]
