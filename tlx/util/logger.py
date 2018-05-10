import logging


class Logger:
    """This logger will last the length of the process.  Only one is created. Further instantiation simply returns
        the existing instance.  Thus only the initial caller gets to name the log.info"""

    log = None

    @staticmethod
    def create_logger(name=None, log_file=None, level=None):
        if not name:
            name = 'tlx'
        logger = logging.getLogger(name)
        logger.setLevel(logging.DEBUG)

        if log_file:
            # create file handler which logs even debug messages
            fh = logging.FileHandler(log_file)
            fh.setLevel(logging.DEBUG)

        # create console handler
        ch = logging.StreamHandler()
        ch.setLevel(getattr(logging, level))

        # create formatter and add it to the handler
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

        ch.setFormatter(formatter)
        logger.addHandler(ch)

        if log_file:  # repeat the above if file output
            fh.setFormatter(formatter)
            logger.addHandler(fh)

        # Do some logging
        logger.debug('Logger initialised ({})'.format(name))

        Logger.log = logger

    def __init__(self, name=None, log_file=None, level='INFO'):
        if not Logger.log:
            Logger.create_logger(name, log_file, level)


def get_log(name=None, log_file=None, level=None):
    logger = Logger(name, log_file, level)
    return logger.log
