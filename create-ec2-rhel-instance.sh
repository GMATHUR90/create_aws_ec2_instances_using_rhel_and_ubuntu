#!/bin/bash

# Variables
INSTANCE_TYPE="t3.medium"          # Instance type
AMI_ID="ami-0583d8c7a9c35822c"    # AMI ID for Amazon Machine Image
KEY_NAME="auto_generated_key"     # Dynamic key pair name
TAG_NAME="aws_test_instance"      # Name tag for the instance

# Fetch default AWS region
echo "Fetching default AWS region..."
DEFAULT_REGION=$(aws configure get region)

if [ -z "$DEFAULT_REGION" ]; then
    echo "Default region is not configured. Set it using 'aws configure set region <region-name>' or export AWS_REGION."
    exit 1
fi
echo "Default region: $DEFAULT_REGION"

# Create Key Pair
echo "Creating a new key pair..."
KEY_FILE="${KEY_NAME}.pem"
aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text > $KEY_FILE

if [ $? -eq 0 ]; then
    chmod 400 $KEY_FILE
    echo "Key pair created successfully: $KEY_FILE"
else
    echo "Failed to create key pair."
    exit 1
fi

# Fetch VPC ID (assuming the first VPC is the default one)
echo "Fetching VPC ID..."
VPC_ID=$(aws ec2 describe-vpcs \
    --query 'Vpcs[0].VpcId' \
    --output text)

if [ -z "$VPC_ID" ]; then
    echo "Failed to fetch VPC ID."
    exit 1
fi
echo "VPC ID fetched successfully: $VPC_ID"

# Fetch Subnet ID and Availability Zone
echo "Fetching Subnet ID and Availability Zone..."
SUBNET_INFO=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[0].[SubnetId, AvailabilityZone]' \
    --output text)

SUBNET_ID=$(echo "$SUBNET_INFO" | awk '{print $1}')
SUBNET_AZ=$(echo "$SUBNET_INFO" | awk '{print $2}')

if [ -z "$SUBNET_ID" ]; then
    echo "No subnet found. Creating a new subnet..."
    CIDR_BLOCK="10.0.1.0/24"
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $CIDR_BLOCK \
        --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text) \
        --query 'Subnet.SubnetId' \
        --output text)

    if [ -z "$SUBNET_ID" ]; then
        echo "Failed to create subnet."
        exit 1
    fi
    echo "Subnet created successfully: $SUBNET_ID"
fi

# Configure Storage Volumes (using gp3)
BLOCK_DEVICE_MAPPINGS='[
    {
        "DeviceName": "/dev/xvda",
        "Ebs": {
            "VolumeSize": 10,
            "DeleteOnTermination": true,
            "VolumeType": "gp3"
        }
    }
]'

# Create Security Group
echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name aws_test_sg \
    --description "Security group for SSH, HTTP, HTTPS access" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Failed to create security group."
    exit 1
fi
echo "Security group created successfully. Group ID: $SECURITY_GROUP_ID"

# Add Rules to Security Group
echo "Adding rules to the security group..."
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0   # SSH
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0   # HTTP
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0  # HTTPS

if [ $? -ne 0 ]; then
    echo "Failed to add rules to the security group."
    exit 1
fi

# Create EC2 Instance
echo "Creating EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --block-device-mappings "$BLOCK_DEVICE_MAPPINGS" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Failed to create EC2 instance."
    exit 1
fi
echo "EC2 Instance created successfully. Instance ID: $INSTANCE_ID"

# Retrieve Public IP
echo "Retrieving public IP address of the instance..."
PUBLIC_IP=""
RETRY_COUNT=0
MAX_RETRIES=5

while [ -z "$PUBLIC_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ -z "$PUBLIC_IP" ]; then
    echo "Public IP not assigned. Allocating Elastic IP..."
    ALLOCATION_ID=$(aws ec2 allocate-address --query 'AllocationId' --output text)
    aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID
    PUBLIC_IP=$(aws ec2 describe-addresses --allocation-ids $ALLOCATION_ID --query 'Addresses[0].PublicIp' --output text)
fi

if [ -z "$PUBLIC_IP" ]; then
    echo "Failed to retrieve or allocate a public IP address."
    exit 1
fi
echo "Instance Public IP: $PUBLIC_IP"

echo "EC2 instance setup completed successfully."

