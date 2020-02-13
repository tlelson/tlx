class Singleton(type):
    """ Use as a metaclass. E.g:
            >>> class PeggedTime(metaclass=Singleton):
            ...     def __init__(self):
            ...         self.dt_now = dt.datetime.now()

        This class returns the same datetime no matter how many instances are created.
    """

    _instances = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]
