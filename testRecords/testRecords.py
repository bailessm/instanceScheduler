import boto3
import os

session = boto3.Session()
dynamodb = session.client('dynamodb')
region = session.region_name

dynamodbTable = os.environ['dynamodbTable'].split("/")[1]

def lambda_handler(event, context):
    response = dynamodb.put_item(
    TableName=dynamodbTable,
    Item={
          "hour": {
            "N": "22"
          },
          "region": {
            "S": region
          },
          "stopTags": {
            "L": [
              {
                "M": {
                  "Key": {
                    "S": "Environment"
                  },
                  "Value": {
                    "S": "dev"
                  }
                }
              },
              {
                "M": {
                  "Key": {
                    "S": "Environment"
                  },
                  "Value": {
                    "S": "qa"
                  }
                }
              }
            ]
          }
        }
    )
    response = dynamodb.put_item(
    TableName=dynamodbTable,
    Item={
          "hour": {
            "N": "10"
          },
          "region": {
            "S": region
          },
          "startTags": {
            "L": [
              {
                "M": {
                  "Key": {
                    "S": "Environment"
                  },
                  "Value": {
                    "S": "dev"
                  }
                }
              },
              {
                "M": {
                  "Key": {
                    "S": "Environment"
                  },
                  "Value": {
                    "S": "qa"
                  }
                }
              }
            ]
          }
        }
    )