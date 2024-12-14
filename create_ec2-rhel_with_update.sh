#!/bin/bash

# Function to create a new unique key pair
create_key_pair() {
  local base_key_name="$1"
  local key_name="$base_key_name"
  local counter=1

  while aws ec2 describe-key-pairs --key-names "$key_name" --query "KeyPairs[*].KeyName" --output text >/dev/null 2>&1; do
    key_name="${base_key_name}-${counter}"
    counter=$((counter + 1))
  done

  echo "Creating key pair: $key_name"
  aws ec2 create-key-pair --key-name "$key_name" --query 'KeyMaterial' --output text > "${key_name}.pem"
  chmod 400 "${key_name}.pem"

  echo "$key_name"
}

# Function to create a new unique security group
create_security_group() {
  local base_group_name="$1"
  local group_name="$base_group_name"
  local counter=1

  while aws ec2 describe-security-groups --group-names "$group_name" --query "SecurityGroups[*].GroupName" --output text >/dev/null 2>&1; do
    group_name="${base_group_name}-${counter}"
    counter=$((counter + 1))
  done

  echo "Creating security group: $group_name"
  local group_id=$(aws ec2 create-security-group --group-name "$group_name" --description "Security group for RHEL EC2 instance" --query 'GroupId' --output text)

  echo "Adding inbound rule to allow SSH access (port 22)"
  aws ec2 authorize-security-group-ingress --group-id "$group_id" --protocol tcp --port 22 --cidr 0.0.0.0/0

  echo "$group_id"
}

# Variables
BASE_KEY_NAME="rhel-key"
BASE_SECURITY_GROUP_NAME="rhel-sg"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0dfcb1ef8550277af"  # Replace with the AMI ID for RHEL in your region
SUBNET_ID="subnet-12345678"      # Replace with your subnet ID

# Step 1: Create a key pair
KEY_NAME=$(create_key_pair "$BASE_KEY_NAME")

# Step 2: Create a security group
SECURITY_GROUP_ID=$(create_security_group "$BASE_SECURITY_GROUP_NAME")

# Step 3: Launch the EC2 instance
if [[ -n "$SUBNET_ID" ]]; then
  echo "Launching RHEL EC2 instance with key pair $KEY_NAME and security group $SECURITY_GROUP_ID"
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --query 'Instances[0].InstanceId' \
    --output text)
else
  echo "Error: SUBNET_ID is not set. Please provide a valid subnet ID."
  exit 1
fi

if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "null" ]]; then
  echo "Instance launched. Instance ID: $INSTANCE_ID"

  # Step 4: Wait for the instance to be in 'running' state
  echo "Waiting for the instance to be in 'running' state..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  echo "Instance is now running."

  # Step 5: Get the public IP of the instance
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

  echo "Instance public IP: $PUBLIC_IP"

  echo "You can SSH into the instance using:"
  echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
else
  echo "Error: Failed to launch the instance. Please check the parameters and try again."
fi

