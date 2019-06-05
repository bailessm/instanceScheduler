#! /bin/bash

for ARGUMENT in "$@"
do

    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   

    case "$KEY" in
            --stackName)    stackName=${VALUE} ;;
            --region)   region=${VALUE} ;;
            --adminEmail) adminEmail=${VALUE} ;;
            --defaultProfile) defaultProfile=${VALUE} ;;  
            *)   
    esac    

done

stackName=${stackName:-'instanceScheduler'}
region=${region:-'us-east-1'}
adminEmail=${adminEmail:-'123@usa.com'}


if [ ! -z $defaultProfile ] 
then 
    export AWS_DEFAULT_PROFILE=$defaultProfile
fi

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
for i in $(find . -name '*py')
do  
    file=$(echo $i | cut -d'/' -f3)
    echo $file
    zipFile=${file//$'.py'/}
    echo $zipFile
    echo $i
    zip $zipFile.zip $i -j
done

aws s3 cp . s3://$bucketName/ --recursive --exclude "*" --include "*.zip"

find . -name '*.zip' | xargs rm

echo "$bucketName was successfully created and the lambda function code was uploaded."

echo "Creating the Instance Scheduler Stack."
##Create Instance Scheduler stack
aws cloudformation create-stack --stack-name $stackName \
    --template-body file://cfTemplate.yaml \
    --parameters ParameterKey=codeBucket,ParameterValue=$bucketName ParameterKey=adminEmail,ParameterValue=$adminEmail \
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

lambdaArn=$(aws cloudformation describe-stacks --stack-name $stackName \
    --query 'Stacks[0].Outputs[?OutputKey==`testRecordsFunction`].OutputValue[]' --region $region)

lambdaArn="${lambdaArn//[}"
lambdaArn="${lambdaArn//]}"
lambdaArn=${lambdaArn//'"'}


aws lambda invoke --function-name $lambdaArn --region $region outputfile.txt
rm outputfile.txt

#Uncomment the following line if you had to change the default profile for this script

if [ ! -z $defaultProfile ] 
then 
    unset AWS_DEFAULT_PROFILE
fi

echo "Instance scheduler deploy is complete."