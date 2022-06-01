import json
import random
import datetime

from google.cloud import pubsub_v1

# retrieve the project variables from terraform config file (terraform.tfvars.json)
f = open('terraform.tfvars.json')
vars = json.loads(f.read())
f.close()


publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(vars['project_id'], vars['topic_id'])


for n in [40, 48, 58, 60, 61, 62, 64, 70, 71, 72]:

    item = {
        "station_id": n,
        "charger_in_use": random.randint(0, 2),
        "charger_total": 2,
        "updated": datetime.datetime.now().__str__()
    }

    # Data must be a bytestring
    data = json.dumps(item)

    # When you publish a message, the client returns a future.
    future = publisher.publish(topic_path, data.encode("utf-8"))
    print(future.result())
