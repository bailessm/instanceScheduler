#! /bin/bash
stackName='instanceScheduler'
region='us-east-1'

#If you use another cli profile for elevated priviledges uncomment the
#followind line and modify it with your profile name.  Also uncomment the
#last line in this file to change back to the default profile after the 
#script completes.

export AWS_DEFAULT_PROFILE=admin

echo "Creating a Bucket to hold the Lambda code."
##Create a bucket to hold lambda function code
aws cloudformation create-stack --stack-name $stackName-Bucket --template-body file://codeBucket.yaml --region $region

##Wait for the bucket to be created
aws cloudformation wait stack-create-complete --stack-name $stackName-Bucket --region $region

##pull the s3Bucket Output from the bucket
s3BucketArn=$(aws cloudformation describe-stacks --stack-name $stackName-Bucket \
    --query 'Stacks[0].Outputs[?OutputKey==`s3Bucket`].OutputValue[]' --region $region)

##Pull the S3 bucket name from the ARN
s3BucketArn="${s3BucketArn//[}"
s3BucketArn="${s3BucketArn//]}"
s3BucketArn=${s3BucketArn//$'\n'/}
s3BucketArn=${s3BucketArn//$'"'/}
s3BucketArn=${s3BucketArn//$' '/}
bucketName=${s3BucketArn//$'arn:aws:s3:::'/}

##upload the lambda code to the code bucket
aws s3 cp . s3://$bucketName/ --recursive --exclude "*" --include "*.zip"

echo "$bucketName was successfully created and the lambda function code was uploaded."

echo "Creating the Instance Scheduler Stack."
##Create Instance Scheduler stack
aws cloudformation create-stack --stack-name $stackName \
    --template-body file://cfTemplate.yaml \
    --parameters ParameterKey=codeBucket,ParameterValue=$bucketName \
    --capabilities CAPABILITY_IAM --region $region

#Wait for the stack to be created
echo "Please wait for the stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $stackName --region $region
echo "The stack application is ready, loading test URLs..."

dbTableArn=$(aws cloudformation describe-stacks --stack-name $stackName \
    --query 'Stacks[0].Outputs[?OutputKey==`DynamoDBTable`].OutputValue[]' --region $region)

##Pull the DDBTable from the ARN
dbTableArn="${dbTableArn//[}"
dbTableArn="${dbTableArn//]}"
dbTableArn=$(tr '/' ';' <<<$dbTableArn)
dbTable="$(echo $dbTableArn | cut -d';' -f2)"
dbTable=${dbTable//$'\n'/}
dbTable=${dbTable//$'"'/}

###Create two records in the dynamodb table as an example. These two rows will affect ec2 instances
###with and Environment Tag that has the values qa or dev.  It will start them at 10 UTC(7AM EDT) and stop
###them at 22 UTC(6PM EDT).
aws dynamodb put-item --table-name $dbTable --item '{"hour": {"N": "10"},"startTags": {"L": [{"M": {"Key": {"S": "Environment"},"Value": {"S": "dev"}}},{"M": {"Key": {"S": "Environment"},"Value": {"S": "qa"}}}]}}' --region $region
aws dynamodb put-item --table-name $dbTable --item '{"hour": {"N": "22"},"stopTags": {"L": [{"M": {"Key": {"S": "Environment"},"Value": {"S": "dev"}}},{"M": {"Key": {"S": "Environment"},"Value": {"S": "qa"}}}]}}' --region $region

#Uncomment the following line if you had to change the default profile for this script

echo "Instance scheduler deploy is complete."
unset AWS_DEFAULT_PROFILE