import boto3
import botocore
import os

def lambda_handler(event, context):
    vpcendpoint1 = os.environ['vpcendpoint1']
    vpcendpoint2 = os.environ['vpcendpoint2']
    routetable = os.environ['routetable']
    region = os.environ['region']
    ec2 = boto3.resource('ec2',region_name=region)
    client = boto3.client('ec2',region_name=region)
    route_table = ec2.RouteTable(routetable)

    if event['alarmData']['state']['value'] == 'ALARM':
        #Remove old route
        try:
            response = client.delete_route(
                DestinationCidrBlock='0.0.0.0/0',
                RouteTableId=routetable
            )
        
        except botocore.exceptions.ClientError as error:
            print(error)
        #Add new route
        try:
            response = route_table.create_route(
                DestinationCidrBlock='0.0.0.0/0',
                VpcEndpointId=vpcendpoint2
            )
            print(f'Updated route to use {vpcendpoint1}')
        except botocore.exceptions.ClientError as error:
            print(error)
        
    elif event['alarmData']['state']['value'] == 'OK':
        #Remove old route
        try:
            response = client.delete_route(
                DestinationCidrBlock='0.0.0.0/0',
                RouteTableId=routetable
            )
        
        except botocore.exceptions.ClientError as error:
            print(error)
        #Add new route
        try:
            response = route_table.create_route(
                DestinationCidrBlock='0.0.0.0/0',
                VpcEndpointId=vpcendpoint1
            )
            print(f'Updated route to use {vpcendpoint1}')
        except botocore.exceptions.ClientError as error:
            print(error)
 
