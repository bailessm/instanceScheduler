#! /bin/bash
#process input variables
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

#set defaults if you didn't specify them
stackName=${stackName:-'instanceScheduler'}
region=${region:-'us-east-1'}
adminEmail=${adminEmail:-'123@usa.com'}

#change the default profile if you specified a temporary one.
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
bucketName=$(aws cloudformation describe-stacks --stack-name $stackName-Bucket \
    --query 'Stacks[0].Outputs[?OutputKey==`s3Bucket`].OutputValue[]' --region $region --output text)

##zip and upload the lambda code to the code bucket
for i in $(find . -name '*py')
do  
    file=$(echo $i | cut -d'/' -f3)
    zipFile=${file//$'.py'/}
    zip $zipFile-latest.zip $i -j
done

aws s3 cp . s3://$bucketName/ --recursive --exclude "*" --include "*-latest.zip"
find . -name '*-latest.zip' | xargs rm

echo "$bucketName was successfully created and the lambda function code was uploaded."

echo "Creating the Instance Scheduler Stack."
##Create Instance Scheduler stack
aws cloudformation create-stack --stack-name $stackName \
    --template-body file://cfTemplate.yaml \
    --parameters ParameterKey=adminEmail,ParameterValue=$adminEmail \
    --capabilities CAPABILITY_IAM --region $region

#Wait for the stack to be created
echo "Please wait for the stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $stackName --region $region
echo "The stack application is ready, loading test URLs..."

###Create two records in the dynamodb table as an example. These two rows will affect ec2 instances
###with and Environment Tag that has the values qa or dev.  It will start them at 10 UTC(7AM EDT) and stop
###them at 22 UTC(6PM EDT).

#get the arn for the lambda function to insert the test records
lambdaArn=$(aws cloudformation describe-stacks --stack-name $stackName \
    --query 'Stacks[0].Outputs[?OutputKey==`testRecordsFunction`].OutputValue[]' --region $region --output text)

#invoke the lambda function to input those records
aws lambda invoke --function-name $lambdaArn --region $region outputfile.txt
rm outputfile.txt

#revert back from the temporary aws profile if you switched
if [ ! -z $defaultProfile ] 
then 
    unset AWS_DEFAULT_PROFILE
fi

echo "Instance scheduler deploy is complete."