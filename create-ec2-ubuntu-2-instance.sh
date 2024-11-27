#!/bin/bash

# Variables
INSTANCE_TYPE="t3.medium"          # Instance type
AMI_ID="ami-0866a3c8686eaeeba"    # AMI ID for Amazon Machine Image
KEY_NAME="kube_master_1"          # Dynamic key pair name
TAG_NAME_BASE="kube_master"       # Base name tag for instances

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

if [ $? -eq 0 ]; then
    echo "VPC ID fetched successfully: $VPC_ID"
else
    echo "Failed to fetch VPC ID."
    exit 1
fi

# Fetch Subnet ID (dynamically select from a supported AZ)
echo "Fetching a supported subnet ID..."
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[0].SubnetId' \
    --output text)

if [ $? -eq 0 ] && [ "$SUBNET_ID" != "None" ]; then
    echo "Using subnet: $SUBNET_ID"
else
    echo "Failed to fetch a valid subnet."
    exit 1
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
    },
    {
        "DeviceName": "/dev/xvdb",
        "Ebs": {
            "VolumeSize": 12,
            "DeleteOnTermination": true,
            "VolumeType": "gp3"
        }
    },
    {
        "DeviceName": "/dev/xvdc",
        "Ebs": {
            "VolumeSize": 18,
            "DeleteOnTermination": true,
            "VolumeType": "gp3"
        }
    }
]'

# Create Security Group
echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name aws_test_sg \
    --description "Security group for SSH, HTTP, HTTPS, and Kubernetes API access" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "Security group created successfully. Group ID: $SECURITY_GROUP_ID"
else
    echo "Failed to create security group."
    exit 1
fi

# Add Rules to Security Group
echo "Adding rules to the security group..."
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0   # SSH
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0   # HTTP
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0  # HTTPS
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 6443 --cidr 0.0.0.0/0 # Kubernetes API Server
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 179 --cidr 0.0.0.0/0  # BGP (Port 179)
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 10250 --cidr 0.0.0.0/0 # Kubelet API

if [ $? -eq 0 ]; then
    echo "Rules added to the security group successfully."
else
    echo "Failed to add rules to the security group."
    exit 1
fi

# Create EC2 Instances one by one with unique tags
echo "Creating EC2 instance 1..."
INSTANCE_ID_1=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --block-device-mappings "$BLOCK_DEVICE_MAPPINGS" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME_BASE}_1}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "EC2 Instance 1 created successfully. Instance ID: $INSTANCE_ID_1"
else
    echo "Failed to create EC2 Instance 1."
    exit 1
fi

echo "Creating EC2 instance 2..."
INSTANCE_ID_2=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --block-device-mappings "$BLOCK_DEVICE_MAPPINGS" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${TAG_NAME_BASE}_2}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ $? -eq 0 ]; then
    echo "EC2 Instance 2 created successfully. Instance ID: $INSTANCE_ID_2"
else
    echo "Failed to create EC2 Instance 2."
    exit 1
fi

# Retrieve Public IPs
echo "Retrieving public IP addresses of the instances..."
for ID in $INSTANCE_ID_1 $INSTANCE_ID_2; do
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    echo "Instance ID: $ID, Public IP: $PUBLIC_IP"
done

