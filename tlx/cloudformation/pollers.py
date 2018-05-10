import boto3
import time
from collections import defaultdict
from tlx.util import get_log
import datetime as dt
now = dt.datetime.now(tz=dt.timezone.utc)
logger = get_log(name='Event-poller', level='DEBUG')
# logger = get_log(name='Event-poller', level='WARN')


## Idea: Wrap this in an async call and when it yeilds. Stop printing events

stack_name = 'my-ledAPI-dev'
cfn_client = boto3.client('cloudformation')
cloudformation = boto3.resource('cloudformation')
stack = cloudformation.Stack(stack_name)

class keydefaultdict(defaultdict):
    def __missing__(self, key):
        if self.default_factory is None:
            raise KeyError( key )
        else:
            ret = self[key] = self.default_factory(key)
            return ret

class MyEvent():
    def __init__(self, cfn_event):
        # convert timestamp to localtime
        self.event = cfn_event
        self._dict = keydefaultdict(lambda key: getattr(self.event, key))
        # self._dict = keydefaultdict(lambda key: str(getattr(self.event, key)), {
                # 'timestamp': getattr(self.event, 'timestamp').isoformat(timespec='milliseconds').replace('T', ' ')
            # })
    def __getitem__(self, key):
        return self._dict[key]

stack_completion_states = [
    'CREATE_COMPLETE',
    'UPDATE_COMPLETE',
    'UPDATE_ROLLBACK_COMPLETE',
]

ids = set()
# resource_types = defaultdict(lambda: set())
stack_updating = True
empty_count = 0
count = 0
logger.debug(f"Start looping")
while stack_updating and empty_count < 10:
    count += 1
    logger.debug(f"loop: {count}")
    # It preloads these so keep the count small
    new_events = 0
    # It preloads these so keep the count small
    try:
        events = sorted([MyEvent(e)
            for e in stack.events.limit(count=20)
        ], key=lambda e: e['timestamp'], reverse=True)
    except cfn_client.exceptions.ClientError as e:
        # TODO: need to differentiate between expired token and stack not exist
        logger.warn(str(e))
        logger.debug(f"Stack not found: empty_count is: {empty_count}")
        # if not empty_count:
            # # Stack delete
            # print("Stack has finished being deleted.")
            # break
        # Otherwise, it does exist yet, wait for it to come up
        logger.warn(f"{str(e)}")
        time.sleep(15)
        continue
    for e in events:
        if ( e['timestamp'] < now
                or e['id'] in ids
                # or e['resource_status'] in resource_types[e['resource_type']]
                ):
            break
        # otherwise print out the event
        new_events += 1
        ids.add(e['id'])
        # resource_types[e['resource_type']].add(e['resource_status'])

        print(f"{e['timestamp']} - {e['resource_type']} - {e['resource_status']} - {e['logical_resource_id']}")

        if e['resource_type'] == 'AWS::CloudFormation::Stack' and e['resource_status'] in stack_completion_states:
            logger.info("Stop condition found. Stopping ... ")
            stack_updating = False
            break
    logger.info(f"{new_events} picked up")

    if new_events == 0:
        time.sleep(5)
        logger.debug(f"No new events picked up. empty_count: {empty_count}")
        empty_count += 1
    else:  # Only interested in consecutive empty events
        empty_count = 0

if empty_count and len(ids) == 0:
    logger.info(f"No stack events found for {stack_name} after the time this was executed ...")

