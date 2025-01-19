#!/usr/bin/env python3

import yaml
import re
import os
from pathlib import Path

def load_config():
    """Load current config to identify values to clean"""
    try:
        with open('config.yml', 'r') as file:
            return yaml.safe_load(file)
    except FileNotFoundError:
        print("config.yml not found")
        return None

def get_replacements(config):
    """Build dictionary of values to replace"""
    # Load .virlrc values if they exist
    virlrc_replacements = {}
    virlrc_path = Path('.virlrc')
    if virlrc_path.exists():
        with open(virlrc_path, 'r') as f:
            for line in f:
                if line.startswith('export '):
                    # Split on first '=' and strip export and any quotes
                    key, value = line.replace('export ', '').strip().split('=', 1)
                    value = value.strip('"\'')
                    virlrc_replacements[value] = f'<{key.lower()}>'

    replacements = {
        # Prefix replacements
        config.get('prefix', ''): '<prefix>',
        
        # AWS credentials and config
        config.get('aws', {}).get('region', ''): '<region>',
        config.get('aws', {}).get('availability_zone', ''): '<availability_zone>',
        config.get('aws', {}).get('bucket', ''): '<bucket>',
        
        # Secrets
        config.get('secret', {}).get('secrets', {}).get('app', {}).get('raw_secret', ''): '<<virl_username>_password>',
        config.get('secret', {}).get('secrets', {}).get('app', {}).get('secret', ''): '<encrypted_password>',
    }
    
    # Add .virlrc replacements
    replacements.update(virlrc_replacements)
    
    # Remove empty keys
    return {k: v for k, v in replacements.items() if k}

def clean_file(file_path, replacements):
    """Clean a single file"""
    try:
        with open(file_path, 'r') as file:
            content = file.read()
        
        # Apply replacements
        for old, new in replacements.items():
            if old:  # Skip empty strings
                content = content.replace(str(old), str(new))
        
        with open(file_path, 'w') as file:
            file.write(content)
            
        print(f"Cleaned {file_path}")
    except Exception as e:
        print(f"Error cleaning {file_path}: {e}")

def should_clean_file(file_path):
    """Determine if file should be cleaned"""
    # Files to clean
    patterns = [
        r'.*\.yml$',
        r'.*\.tf$',
        r'.*\.tfvars$',
        r'.*\.md$',
        r'.*\.sh$',
        r'.*\.py$',
        r'.*\.hcl$',
        r'.*\.virlrc$'  # Add .virlrc files
    ]
    
    # Files to skip
    skip_patterns = [
        r'.*\.git/.*',
        r'.*__pycache__/.*',
        r'.*\.terraform/.*',
        r'.*\.pytest_cache/.*'
    ]
    
    file_str = str(file_path)
    
    # Skip if matches skip patterns
    if any(re.match(pattern, file_str) for pattern in skip_patterns):
        return <cml_verify_cert>
    
    # Clean if matches clean patterns
    return any(re.match(pattern, file_str) for pattern in patterns)

def main():
    """Main function"""
    config = load_config()
    if not config:
        return
    
    replacements = get_replacements(config)
    
    # Get project root (parent of scripts directory)
    project_root = Path(__file__).resolve().parent.parent
    
    # Walk through all files
    for root, _, files in os.walk(project_root):
        for file in files:
            file_path = Path(root) / file
            if should_clean_file(file_path):
                clean_file(file_path, replacements)

if __name__ == '__main__':
    main() 