import json
import string
import random
from uuid import uuid4
from decimal import Decimal
import datetime as dt


def get_random_eventid():
    """Returns a 32 char random hash garenteeing lowercase letter at the begining"""
    return random.choice(string.ascii_lowercase) + uuid4().hex[1:]


def json_loads(x, **kwargs):
    """Loads json for DynamoDB (Numerical types go to Decimal)"""
    return json.loads(x, parse_int=Decimal, parse_float=Decimal, **kwargs)


def json_dumps(x, **kwargs):
    """Dumps json for DynamoDB (Numerical types go to Decimal) use indent=4 if required"""
    return json.dumps(x, cls=DecimalEncoder, separators=(',', ': '), sort_keys=True, **kwargs)


def string_from_datetime(d, sep=None):
    """string format from python datetime"""
    return d.replace(tzinfo=None).isoformat(sep=sep, timespec='milliseconds')


class DecimalEncoder(json.JSONEncoder):
    """ Makes type conversions to allow JSON serialisation using data types commonly used in the project
        Decimal -> float
        datetime -> ISO string
    """

    def default(self, o, markers=None):
        if isinstance(o, Decimal):
            return float(o)
        if isinstance(o, dt.datetime):
            return string_from_datetime(o)
        return json.JSONEncoder(self).default(o, markers)
