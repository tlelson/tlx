import boto3
from collections import defaultdict
import datetime as dt
now = dt.datetime.now(tz=dt.timezone.utc)

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
resource_types = defaultdict(lambda: set())
stack_updating = True
empty_count = 0
while stack_updating and empty_count < 10:
    # It preloads these so keep the count small
    new_events = 0
    # It preloads these so keep the count small
    events = sorted([MyEvent(e)
        for e in stack.events.limit(count=20)
    ], key=lambda e: e['timestamp'], reverse=True)
    for e in events:
        if ( e['timestamp'] < now
                or e['id'] in ids
                or e['resource_status'] in resource_types[e['resource_type']]):
            break
        # otherwise print out the event
        new_events += 1
        ids.add(e['id'])
        resource_types[e['resource_type']].add(e['resource_status'])

        print(f"{e['timestamp']} - {e['resource_type']} - {e['resource_status']}")

        if e['resource_type'] == 'AWS::CloudFormation::Stack' and e['resource_status'] in stack_completion_states:
            stack_updating = False

    if new_events == 0:
        empty_count += 1

