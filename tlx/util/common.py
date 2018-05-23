from uuid import uuid4


def _stringify(d):
    """Returns a ISO 8601 string from a datetime object. """
    return d.replace(tzinfo=None).isoformat(' ', timespec='milliseconds')


def get_uuid():
    """Returns a 32 char random hash garenteeing lowercase letter at the begining"""
    return uuid4().hex
