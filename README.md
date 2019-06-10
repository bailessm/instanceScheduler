# instanceScheduler
Serverless Application to start and stop ec2 instances on a schedule 

This initial deployment with the example entries will affect ec2 instances in the region you launched the CF template in with an Environment Tag that has the values qa or dev.  It will start those instances at 10 UTC(7AM EDT) and stop them at 22 UTC(6PM EDT).

The application contains a DynamoDB table, 3 lambda functions, one cloudwatch rule, and two sns topics. The DynamoDB Table contains an item for each hour per rgion that you would like to start or stop instances. hour is the partition key and region is the sort key for that table.

The record added to start Instances.
```json
{
  "hour": 10,
  "region": "us-east-1",
  "startTags": [
    {
      "Key": "Environment",
      "Value": "dev"
    },
    {
      "Key": "Environment",
      "Value": "qa"
    }
  ]
}
```
The Record added to stop those tagged instances.
```json
{
  "hour": 22,
  "region": "us-east-1",
  "stopTags": [
    {
      "Key": "Environment",
      "Value": "dev"
    },
    {
      "Key": "Environment",
      "Value": "qa"
    }
  ]
}
```
With the default cron statement for the instanceScheduler lambda funtion, it will poll every hour on the hour Monday Thru Friday to see if you have any tasks to perform at that time.  If it does, it will publish a message to the appropriate SNS topic to start or stop the instances with the included tags.  

# Deployment 
## MacOS

In the folder that you want to download the instanceScheduler folder and files to run the following command.

~~~~
git clone https://github.com/bailessm/instanceSchduler.git
cd instanceScheduler
bash deploy.sh
~~~~

You can pass the following variables if you would like to modify the defaults to deploy.sh. All named variables are optional and must be passed as --"variable name"="variable value"

~~~~
  --stackName=
  --region=
  --adminEmail=
  --defaultProfile=

  #example...
  bash deploy.sh --stackName=instanceScheduler-West --region=us-west-2 --adminEmail=123@usa.com --defaultProfile=admin
~~~~

## Windows
 
 From a powershell window run the following script.
~~~~
git clone https://github.com/bailessm/instanceSchduler.git
cd instanceScheduler
./deploy.ps1

~~~~

You can pass the following optional variables if you would like to modify the defaults to deploy.ps1.

~~~~

  -stackName
  -region
  -adminEmail
  -defaultProfile

~~~~

