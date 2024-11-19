#!/bin/bash

# Fetch the default region from AWS CLI configuration
DEFAULT_REGION=$(aws configure get region)

if [ -z "$DEFAULT_REGION" ]; then
  echo "AWS default region is not configured. Please configure it using 'aws configure'."
  exit 1
fi

echo "Using AWS region: $DEFAULT_REGION"

# Fetch VPC ID
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text --region "$DEFAULT_REGION")
if [ "$VPC_ID" == "None" ]; then
  echo "No VPCs found in the region $DEFAULT_REGION."
  exit 1
fi
echo "VPC ID: $VPC_ID"

# Fetch Subnet ID
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text --region "$DEFAULT_REGION")
if [ "$SUBNET_ID" == "None" ]; then
  echo "No Subnets found in the VPC $VPC_ID."
  exit 1
fi
echo "Subnet ID: $SUBNET_ID"

# Create Security Group
SECURITY_GROUP_NAME="aws_test_11_sg"
SG_DESCRIPTION="Security group for aws_test_11"
SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "$SG_DESCRIPTION" --vpc-id "$VPC_ID" --query 'GroupId' --output text --region "$DEFAULT_REGION")
echo "Security Group ID: $SG_ID"

# Add Ingress Rules to Security Group
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$DEFAULT_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$DEFAULT_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$DEFAULT_REGION"
echo "Ingress rules added to Security Group $SECURITY_GROUP_NAME."

# Launch EC2 Instance
INSTANCE_NAME="aws_test_11"
AMI_ID="ami-0583d8c7a9c35822c"
INSTANCE_TYPE="t3.medium"
KEY_NAME="aws_test_11"
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SG_ID" --subnet-id "$SUBNET_ID" --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":10,"VolumeType":"gp3"}},{"DeviceName":"/dev/xvdb","Ebs":{"VolumeSize":12,"VolumeType":"gp3"}},{"DeviceName":"/dev/xvdc","Ebs":{"VolumeSize":18,"VolumeType":"gp3"}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" --query 'Instances[0].InstanceId' --output text --region "$DEFAULT_REGION")
echo "EC2 Instance ID: $INSTANCE_ID"

# Fetch Public IP Address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region "$DEFAULT_REGION")
echo "Public IP Address: $PUBLIC_IP"

