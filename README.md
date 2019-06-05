# instanceScheduler
Serverless Application to start and stop ec2 instances on a schedule 

This initial deployment with the example entries will affect ec2 instances with an Environment Tag that has the values qa or dev.  It will start those instances at 10 UTC(7AM EDT) and stop them at 22 UTC(6PM EDT).

The application contains a DynamoDB table, 3 lambda functions, one cloudwatch rule, and two sns topics. The DynamoDB Table contains an item for each hour that you would like to start or stop instances.

The record added to start Instances.
```json
{
  "hour": 10,
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

Since this is SNS you can also send an email when these start and stop messages are sent. Modify the variable on line 4 of deploy.sh with your email address to email that.

~~~~
adminEmail='123@usa.com'
~~~~

In the folder that you want to download the instanceScheduler folder and files to run the following command.

~~~~
git clone https://github.com/bailessm/instanceSchduler.git
cd instanceScheduler
bash deploy.sh
~~~~

This script will use your aws cli credentials to create all of the aws assets for this project.  If you use a different cli profile for elevated priviledges, you can uncomment line 10 and 67 of deploy.sh
and modify line 10 to meet your needs.

## Windows
 
 From a powershell window run the following script.
~~~~
git clone https://github.com/bailessm/instanceSchduler.git
cd instanceScheduler
./deploy.ps1

~~~~

You can pass the following variables if you would like to modify the defaults to deploy.ps1.

~~~~
Param(
    [string]$stackName="instanceScheduler-test",
    [string]$region="us-east-1",
    [string]$adminEmail="123@usa.com",
    $defaultProfile=""
)
~~~~

