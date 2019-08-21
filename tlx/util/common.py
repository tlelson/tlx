import string
import random
from uuid import uuid4


def _stringify(d):
    """Returns a ISO 8601 string from a datetime object. """
    return d.replace(tzinfo=None).isoformat(' ', timespec='milliseconds')


def get_uuid():
    """Returns a 32 char random hash garenteeing lowercase letter at the begining"""
    return uuid4().hex


def string_from_datetime(d, sep=None):
    """string format from python datetime"""
    return d.replace(tzinfo=None).isoformat(sep=sep, timespec='milliseconds')


def get_random_eventid():
    """ Returns a 32 char random hash garenteeing lowercase letter at the begining.
        (DynamoDB has issues with digits at the start)
    """
    return random.choice(string.ascii_lowercase) + uuid4().hex[1:]
