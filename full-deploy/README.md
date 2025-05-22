# Palo Alto Firewall Deployment with Gateway Load Balancer

## Prerequisites

1. **Update the `terraform.tfvars` file**:
    - Omit the access/secret access keys if the machine you are using already has AWS access.
    - Comment out `access_key` and `secret_key` in `main.tf` if omitted from the `tfvars` file.
    - Ensure the EC2 SSH keypair is created and downloaded. This will be used for SSH access later.
    - Update the AMI ID. Accept the Palo Alto firewall terms from the marketplace related to the AMI.

2. **Subnet Requirements**:
    - The subnet in the `tfvars` file must be at least a `/23` to accommodate multiple subnets.

3. **Availability Zones**:
    - 2 AZs are mandatory for the load balancer.

4. **Transit Gateway**:
    - Ensure the transit gateway is deployed.
    - Update the `tfvars` file with the `txid`.

## Functionality of `new_lambda.py`

The `new_lambda.py` script is an AWS Lambda function designed to dynamically update VPC route tables in response to CloudWatch alarms. Its main functionality is:

- When a monitored alarm enters the `ALARM` state, the Lambda function removes the default route (`0.0.0.0/0`) from the specified route table and adds a new default route pointing to surviving vpcendpoint.
- When the alarm returns to the `OK` state, the function restores the default route to point to the original vpcendpoint.
- The Lambda uses environment variables for the VPC endpoint IDs, route table ID, and AWS region.
- This enables automated failover or traffic redirection between two VPC endpoints based on health or monitoring events, supporting high availability and resilience in your network design.