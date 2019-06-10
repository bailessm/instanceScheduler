import boto3
import json
import os
from datetime import datetime

session = boto3.Session()
dynamodb = session.client('dynamodb')
sns = session.client('sns')
region = session.region_name

stopTopic = os.environ['stopTopic']
startTopic = os.environ['startTopic']
dynamodbTable = os.environ['dynamodbTable'].split("/")[1]

def lambda_handler(event, context):
    #pull dynamodb item for the current utc hour
    response = dynamodb.get_item(
        TableName=dynamodbTable,
        Key={
            'hour': {
                'N': str(datetime.utcnow().hour),
            },
            "region": {
                "S": region
            }

        }
    )
    print(datetime.utcnow().hour)
    #print(response)
    if 'Item' in response:
        
        #check for tags to generate events that start instances
        if 'stopTags' in response['Item']:
            keys = response['Item']['stopTags']['L']
            for u in keys:
                key = u['M']['Key']['S']
                value = u['M']['Value']['S']
                tag = ':'.join([key,value])
                message = ''.join(['{"Key":"',key,'","Value":"',value,'"}'])
                snsResponse = sns.publish(
                    TopicArn=stopTopic,    
                    Message=json.dumps({'default': json.dumps(message),
                                        'email': message}),
                    MessageStructure='json',
                    Subject='Instances with the below tags will be stopped'
                )
            print(snsResponse)
            
        #check for tags to generate events to start instances 
        if 'startTags' in response['Item']:
            keys = response['Item']['startTags']['L']
            for u in keys:
                key = u['M']['Key']['S']
                value = u['M']['Value']['S']
                tag = ':'.join([key,value])
                message = ''.join(['{"Key":"',key,'","Value":"',value,'"}'])
                snsResponse = sns.publish(
                    TopicArn=startTopic,    
                    Message=json.dumps({'default': json.dumps(message),
                                        'email': message}),
                    MessageStructure='json',
                    Subject='Instances with the below tags will be started'
                )
                print(snsResponse)
    else:
        print('No Items returned')

