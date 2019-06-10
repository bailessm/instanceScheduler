Param(
    [string]$stackName="instanceScheduler-test",
    [string]$region="us-east-1",
    [string]$adminEmail="123@usa.com",
    [string]$defaultProfile=""
)
Import-Module AWSPowerShell.NetCore

if(-Not ($defaultProfile -eq "" )){
    Set-AWSCredential -ProfileName $defaultProfile 
}

write-host("Creating a Bucket to hold the Lambda code.")
##Create a bucket to hold lambda function code
$Stack = @{
    StackName = "$stackName-Bucket"
    Region = $region
    TemplateBody = @'
Resources:
  mybucket:
    Type: AWS::S3::Bucket
Outputs:
  s3Bucket:
    Description: 'The bucket to store lambdafunction code in'
    Value: !Ref mybucket
    Export:
      Name: !Sub "${AWS::StackName}-s3Bucket"
'@
}
New-CFNStack @Stack

##Wait for the bucket to be created
Wait-CFNStack -StackName "$stackName-Bucket" -Region $region

##pull the s3Bucket Output from the bucket
$bucketName=$(Get-CFNStackResource -StackName "$stackName-Bucket" -Region $region -LogicalResourceId "mybucket").PhysicalResourceId

##compres and upload the lambda code to the code bucket
Write-S3Object -BucketName $bucketName -File ./ps1-packages/instanceScheduler.zip -Key instanceScheduler-latest.zip
Write-S3Object -BucketName $bucketName -File ./ps1-packages/startInstances.zip -Key startInstances-latest.zip
Write-S3Object -BucketName $bucketName -File ./ps1-packages/stopInstances.zip -Key stopInstances-latest.zip
Write-S3Object -BucketName $bucketName -File ./ps1-packages/testRecords.zip -Key testRecords-latest.zip
Write-S3Object -BucketName $bucketName -File ./cfTemplate.yaml -Key cfTemplate.yaml

write-host("$bucketName was successfully created and the lambda function code was uploaded.")

write-host("Creating the Instance Scheduler Stack.")

$p2 = new-object Amazon.CloudFormation.Model.Parameter    
$p2.ParameterKey = "adminEmail"
$p2.ParameterValue = "$adminEmail"

New-CFNStack -StackName $stackName -Capability CAPABILITY_IAM `
    -TemplateURL "https://$bucketName.s3.amazonaws.com/cfTemplate.yaml" `
    -Parameter @( $p2 ) `
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