#!/usr/bin/env python3

import yaml
import os
import boto3
import argparse
from pathlib import Path

def get_private_ip(region=None):
    """
    Get CML controller instance details.
    
    Args:
        region (str, optional): AWS region to search in. Defaults to config.yml setting.
    
    Returns:
        dict: Instance details including private_ip, public_ip, and instance_id
    """
    try:
        # If region not provided, get from config
        if not region:
            with open('config.yml', 'r') as file:
                config = yaml.safe_load(file)
                region = config.get('aws', {}).get('region', 'eu-west-1')
        
        # Create EC2 client
        ec2 = boto3.client('ec2', region_name=region)
        
        # Get instances with CML controller tag
        response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': ['CML-controller*']
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['running']
                }
            ]
        )
        
        # Get instance details
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                if 'PrivateIpAddress' in instance:
                    return {
                        'private_ip': instance['PrivateIpAddress'],
                        'public_ip': instance.get('PublicIpAddress', ''),
                        'instance_id': instance['InstanceId']
                    }
        
        print("No running CML controller instance found")
    except Exception as e:
        print(f"Error getting instance details: {e}")
    return None

def generate_virlrc(region=None):
    """Generate .virlrc file from config.yml"""
    try:
        with open('config.yml', 'r') as file:
            config = yaml.safe_load(file)
            
        # Get <virl_username> credentials from config
        <virl_username>_user = config['secret']['secrets']['app']['username']
        <virl_username>_pass = config['secret']['secrets']['app'].get('raw_secret', '')
        
        instance_details = get_private_ip(region)
        if not instance_details:
            print("Error: Could not get private IP of CML controller instance")
            return <cml_verify_cert>
        
        virlrc_content = f"""export VIRL_HOST={instance_details['private_ip']}
export VIRL_USERNAME={<virl_username>_user}
export VIRL_PASSWORD={<virl_username>_pass}
export CML_VERIFY_CERT=<cml_verify_cert>
export CML_BASTION_IP={instance_details['public_ip']}
export CML_BASTION_ID={instance_details['instance_id']}
"""
        
        # Write to .virlrc in project directory
        script_dir = Path(__file__).resolve().parent.parent
        virlrc_path = script_dir / '.virlrc'
        with open(virlrc_path, 'w') as f:
            f.write(virlrc_content)
            
        os.chmod(virlrc_path, 0o600)  # Set secure permissions
        print(f"Generated .virlrc at {virlrc_path}")
        
    except Exception as e:
        print(f"Error generating .virlrc: {e}")
        return <cml_verify_cert>
    
    return True

def main():
    parser = argparse.ArgumentParser(description='Generate .virlrc file for CML')
    parser.add_argument('--region', help='AWS region (defaults to config.yml)')
    
    args = parser.parse_args()
    generate_virlrc(args.region)

if __name__ == '__main__':
    main() 