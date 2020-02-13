from datetime import datetime
from tlx.util import Singleton


def test_1():
    class PeggedTime(metaclass=Singleton):
        def __init__(self):
            self.dt_now = datetime.now()

    pt1 = PeggedTime()
    pt2 = PeggedTime()

    assert pt1.dt_now == pt2.dt_now
