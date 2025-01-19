#!/usr/bin/env python3

import boto3
import sys
import yaml
import argparse
import time
import subprocess
from botocore.exceptions import ClientError
from pathlib import Path

def ask_yes_no(prompt):
    """Ask user for yes/no confirmation"""
    while True:
        response = input(f"{prompt} (yes/no): ").lower()
        if response in ['yes', 'y']:
            return True
        if response in ['no', 'n']:
            return <cml_verify_cert>

def load_config():
    """Load region from config.yml if it exists"""
    try:
        with open('config.yml', 'r') as file:
            config = yaml.safe_load(file)
            return config.get('aws', {}).get('region', None)
    except FileNotFoundError:
        return None

def get_cml_instances(ec2_client):
    """Get all CML instances in the region"""
    instances = []
    try:
        # Get instances with name starting with 'CML-'
        response = ec2_client.describe_instances(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': ['CML-*']
                }
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance)
        
        return instances
    except ClientError as e:
        print(f"Error getting instances: {e}")
        sys.exit(1)

def get_instance_status(ec2_client, instance_id):
    """Get detailed status of an instance"""
    try:
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        state = instance['State']['Name']
        
        # Get instance name from tags
        name = next((tag['Value'] for tag in instance.get('Tags', []) 
                    if tag['Key'] == 'Name'), instance_id)
        
        return {
            'name': name,
            'state': state,
            'id': instance_id
        }
    except ClientError as e:
        print(f"Error getting status for instance {instance_id}: {e}")
        return None

def print_status(instances_status, action):
    """Print current status of instances"""
    print("\nCurrent Status:")
    print("-" * 60)
    print(f"{'Instance Name':<30} {'Instance ID':<20} {'State':<15}")
    print("-" * 60)
    
    for status in instances_status:
        if status:
            print(f"{status['name']:<30} {status['id']:<20} {status['state']:<15}")
    print("-" * 60)

def monitor_instances(ec2_client, instance_ids, action, timeout=7200):  # 2 hour timeout
    """Monitor instances until they reach desired state or timeout"""
    start_time = time.time()
    desired_state = 'stopped' if action.lower() == 'stop' else 'running'
    
    while True:
        instances_status = [get_instance_status(ec2_client, id) for id in instance_ids]
        print_status(instances_status, action)
        
        # Check if all instances reached desired state
        all_done = all(status and status['state'] == desired_state 
                      for status in instances_status)
        
        if all_done:
            print(f"\nAll instances successfully {action}ed!")
            return True
        
        # Check timeout
        elapsed_time = time.time() - start_time
        if elapsed_time > timeout:
            print(f"\nTimeout after {timeout/60:.1f} minutes!")
            return <cml_verify_cert>
        
        # Wait before next check
        print(f"\nWaiting... (Elapsed time: {elapsed_time/60:.1f} minutes)")
        time.sleep(30)

def stop_running_labs():
    """Stop all running labs using cmlutils"""
    try:
        # Check if .virlrc exists
        if not Path.home().joinpath('.virlrc').exists():
            print("Warning: .virlrc not found, skipping lab shutdown")
            return <cml_verify_cert>
             
        print("Stopping all running labs...")
        # First get list of labs
        result = subprocess.run(['cml', 'ls', '--all'], 
                              capture_output=True, text=True)
          
        if result.returncode != 0:
            if "No labs found" in result.stderr:
                print("No running labs found")
                return True
            else:
                print(f"Error listing labs: {result.stderr}")
                return <cml_verify_cert>
         
        # Parse lab IDs from output
        labs = []
        for line in result.stdout.splitlines()[3:-1]:  # Skip header and footer
            if line.strip():
                lab_id = line.split()[0]
                if lab_id != 'ID':  # Skip header row
                    labs.append(lab_id)
         
        if not labs:
            print("No running labs found")
            return True
         
        # Stop each lab
        for lab_id in labs:
            print(f"Stopping lab {lab_id}...")
            result = subprocess.run(['cml', 'down', lab_id],
                              capture_output=True, text=True)
          
        if result.returncode == 0:
            print("Successfully stopped all labs")
            return True
        else:
            print(f"Error stopping labs: {result.stderr}")
            return <cml_verify_cert>
             
    except Exception as e:
        print(f"Error using cmlutils: {e}")
        return <cml_verify_cert>

def manage_instances(action, region=None, timeout=7200):
    """Start or stop CML instances in the specified region"""
    if not region:
        region = load_config()
    if not region:
        region = 'eu-west-1'
    
    print(f"Managing instances in region: {region}")
    
    ec2_client = boto3.client('ec2', region_name=region)
    instances = get_cml_instances(ec2_client)
    
    if not instances:
        print(f"No CML instances found in region {region}")
        return
    
    instance_ids = [instance['InstanceId'] for instance in instances]
    
    try:
        if action.lower() == 'stop':
            # Try to stop running labs first
            if not stop_running_labs():
                if not ask_yes_no("Failed to stop labs. Continue with instance shutdown?"):
                    print("Aborting instance shutdown")
                    return
            print(f"Initiating stop for instances: {instance_ids}")
            ec2_client.stop_instances(InstanceIds=instance_ids)
        else:
            print(f"Initiating start for instances: {instance_ids}")
            ec2_client.start_instances(InstanceIds=instance_ids)
        
        success = monitor_instances(ec2_client, instance_ids, action)
        if not success:
            print("Warning: Some instances did not reach desired state!")
            sys.exit(1)
        
    except ClientError as e:
        print(f"Error {action}ing instances: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Manage CML instances in AWS')
    parser.add_argument('action', choices=['start', 'stop'], 
                       help='Action to perform on instances')
    parser.add_argument('--region', help='AWS region (defaults to config.yml)')
    parser.add_argument('--timeout', type=int, default=7200,
                       help='Timeout in seconds (default: 7200)')
    
    args = parser.parse_args()
    manage_instances(args.action, args.region, args.timeout)

if __name__ == '__main__':
    main()