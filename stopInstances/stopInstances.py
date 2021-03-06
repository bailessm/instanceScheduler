import json
import boto3

session = boto3.Session()
ec2 = session.resource('ec2')
region = session.region_name

def lambda_handler(event, context):
    message = json.loads(event['Records'][0]['Sns']['Message'])
    message = json.loads(message)
    
    print(message["Key"])
    print(message["Value"])
    filters = [{
            'Name': ":".join(['tag',message["Key"]]),
            'Values': [message["Value"]]
        },
        {
            'Name': 'instance-state-name', 
            'Values': ['running']
        }
    ]
    
    #filter the instances
    instances = ec2.instances.filter(Filters=filters)
    print(instances)
    RunningInstances = [instance.id for instance in instances]
    print(RunningInstances)
    
    print(len(RunningInstances))
    
    if len(RunningInstances) > 0:
        #perform the shutdown
        shuttingDown = ec2.instances.filter(InstanceIds=RunningInstances).stop()
        print(shuttingDown)
    
