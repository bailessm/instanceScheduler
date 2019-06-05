
Param(
    [string]$stackName="instanceScheduler-test",
    [string]$region="us-east-1",
    [string]$adminEmail="123@usa.com",
    [string]$defaultProfile=""
)

if(-Not ($defaultProfile -eq "" )){
    Set-AWSCredential -ProfileName $defaultProfile 
}

write-host("Creating a Bucket to hold the Lambda code.")
##Create a bucket to hold lambda function code
$Stack = @{
    StackName = "$stackName-bucket"
    Region = $region
    TemplateBody = @'
Resources:
  mybucket:
    Type: AWS::S3::Bucket
Outputs:
  s3Bucket:
    Description: 'The bucket to store lambdafunction code in'
    Value: !GetAtt mybucket.Arn
'@
}
New-CFNStack @Stack

##Wait for the bucket to be created
Wait-CFNStack -StackName "$stackName-bucket" -Region $region

##pull the s3Bucket Output from the bucket
$bucketName=$(Get-CFNStackResource -StackName "$stackName-bucket" -Region $region -LogicalResourceId "mybucket").PhysicalResourceId

##compres and upload the lambda code to the code bucket
Write-S3Object -BucketName $bucketName -File ./psZipCode/instanceScheduler-tmp.zip -Key instanceScheduler.zip
Write-S3Object -BucketName $bucketName -File ./psZipCode/startInstances-tmp.zip -Key startInstances.zip
Write-S3Object -BucketName $bucketName -File ./psZipCode/stopInstances-tmp.zip -Key stopInstances.zip
Write-S3Object -BucketName $bucketName -File ./psZipCode/testRecords-tmp.zip -Key testRecords.zip
Write-S3Object -BucketName $bucketName -File ./cfTemplate.yaml -Key cfTemplate.yaml

write-host("$bucketName was successfully created and the lambda function code was uploaded.")

write-host("Creating the Instance Scheduler Stack.")

##Create Instance Scheduler stack
$p1 = new-object Amazon.CloudFormation.Model.Parameter    
$p1.ParameterKey = "codeBucket"
$p1.ParameterValue = $bucketName

$p2 = new-object Amazon.CloudFormation.Model.Parameter    
$p2.ParameterKey = "adminEmail"
$p2.ParameterValue = "$adminEmail"

New-CFNStack -StackName $stackName -Capability CAPABILITY_IAM `
    -TemplateURL "https://$bucketName.s3.amazonaws.com/cfTemplate.yaml" `
    -Parameter @( $p1, $p2 ) `
    -Region $region

#Wait for the stack to be created
write-host("Please wait for the stack to be created...")
Wait-CFNStack -StackName $stackName -Region $region -Timeout 300
write-host("The stack application is ready, loading test URLs...")

$testRecordsFunction=$(Get-CFNStackResource -StackName $stackName -Region $region -LogicalResourceId "testRecordsFunction").PhysicalResourceId

###Create two records in the dynamodb table as an example. These two rows will affect ec2 instances
###with and Environment Tag that has the values qa or dev.  It will start them at 10 UTC(7AM EDT) and stop
###them at 22 UTC(6PM EDT).
Start-Sleep -s 15
Invoke-LMFunction -FunctionName $testRecordsFunction -Region $region

#aws dynamodb put-item --table-name $dbTable --item '{"hour": {"N": "10"},"startTags": {"L": [{"M": {"Key": {"S": "Environment"},"Value": {"S": "dev"}}},{"M": {"Key": {"S": "Environment"},"Value": {"S": "qa"}}}]}}' --region $region
#aws dynamodb put-item --table-name $dbTable --item '{"hour": {"N": "22"},"stopTags": {"L": [{"M": {"Key": {"S": "Environment"},"Value": {"S": "dev"}}},{"M": {"Key": {"S": "Environment"},"Value": {"S": "qa"}}}]}}' --region $region

#Uncomment the following line if you had to change the default profile for this script

write-host("Instance scheduler deploy is complete.")