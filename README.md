# Create AWS EC2 Instance on RHEL

This repository provides a script to automate the creation of an AWS EC2 instance running Red Hat Enterprise Linux (RHEL). 

## Features
- Automates the process of launching an EC2 instance.
- Configures basic instance settings like instance type, security groups, and key pairs.
- Optimized for RHEL environments.

## Files in the Repository
1. **`create-ec2-instance.sh`**: Shell script to automate the EC2 instance creation.
2. **`README.md`**: Documentation for the repository.

## Prerequisites
Before using the script, ensure the following:
- An active AWS account.
- AWS CLI installed and configured with appropriate credentials.
- Necessary permissions to create EC2 instances, security groups, and key pairs.

## Usage Instructions
### 1. **Clone the Repository**:
```bash
   git clone <repository-url>
   cd create_aws_ec2_instance_rhel-main
```
### 2. **Make the Script Executable:**
```bash
chmod +x create-ec2-instance.sh
```
### 3. **Run the Script:**
```bash
./create-ec2-instance.sh
```
### 4. **Follow the Prompts:**
Provide inputs as prompted by the script to configure and launch the EC2 instance.

## **Customization**
You can modify the create-ec2-instance.sh script to:

- Change the instance type (e.g., t2.micro, t3.medium).
- Update the default AMI ID for RHEL.
- Customize security group rules and other configurations.

## Troubleshooting
- Ensure AWS CLI is installed and properly configured.
- Verify that your IAM user/role has sufficient permissions to perform EC2 operations.
- Check the AWS CLI documentation for common errors: AWS CLI Docs.

## License
This project is open-source and available under the MIT License. Feel free to use and modify it as needed.
