def _stringify(d):
    """Returns a ISO 8601 string from a datetime object. """
    return d.replace(tzinfo=None).isoformat(' ', timespec='milliseconds')
