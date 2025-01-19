#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

cd $(dirname $0)

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    
    while true; do
        # No need for additional prompt suffix since it's in the question now
        read -p "$prompt " answer
        answer=$(echo "${answer:-$default}" | tr '[:upper:]' '[:lower:]')
        case $answer in
            yes | y | true | 1)
                return 0
                ;;
            no | n | false | 0)
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Function to generate random prefix
generate_random_prefix() {
    # Generate random 8 character string (lowercase alphanumeric)
    cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | fold -w 8 | head -n 1
}

# Function to validate prefix
validate_prefix() {
    local prefix=$1
    # Check for valid AWS resource naming (lowercase alphanumeric and hyphens)
    if [[ ! $prefix =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
        echo "Error: Prefix must contain only lowercase letters, numbers, and hyphens"
        echo "       Must start and end with letter or number"
        return 1
    fi
    if [ ${#prefix} -gt 20 ]; then
        echo "Error: Prefix must be 20 characters or less"
        return 1
    fi
    return 0
}

# Ask for and validate prefix
while true; do
    read -p "Enter your prefix for AWS resources (random) [default: random]: " PREFIX
    if [ -z "$PREFIX" ]; then
        PREFIX=$(generate_random_prefix)
        echo "Using random prefix: $PREFIX"
    fi
    if validate_prefix "$PREFIX"; then
        break
    fi
done

echo "Using prefix: $PREFIX"

# Function to map AWS region to city name
get_region_city() {
    local region=$1
    case $region in
        # EMEA Regions
        "eu-west-1")
            echo "dublin"
            ;;
        "eu-west-2")
            echo "london"
            ;;
        "eu-west-3")
            echo "paris"
            ;;
        "eu-central-1")
            echo "frankfurt"
            ;;
        "eu-central-2")
            echo "zurich"
            ;;
        "eu-south-1")
            echo "milan"
            ;;
        "eu-south-2")
            echo "madrid"
            ;;
        "eu-north-1")
            echo "stockholm"
            ;;
        # US Regions
        "us-east-1")
            echo "virginia"
            ;;
        "us-east-2")
            echo "ohio"
            ;;
        "us-west-1")
            echo "california"
            ;;
        "us-west-2")
            echo "oregon"
            ;;
        # APAC Regions
        "ap-east-1")
            echo "hongkong"
            ;;
        "ap-south-1")
            echo "mumbai"
            ;;
        "ap-south-2")
            echo "hyderabad"
            ;;
        "ap-northeast-1")
            echo "tokyo"
            ;;
        "ap-northeast-2")
            echo "seoul"
            ;;
        "ap-northeast-3")
            echo "osaka"
            ;;
        "ap-southeast-1")
            echo "singapore"
            ;;
        "ap-southeast-2")
            echo "sydney"
            ;;
        "ap-southeast-3")
            echo "jakarta"
            ;;
        "ap-southeast-4")
            echo "melbourne"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Ask for AWS region
while true; do
    read -p "Enter AWS region (default: eu-west-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-eu-west-1}
    
    REGION_CITY=$(get_region_city "$AWS_REGION")
    if [ "$REGION_CITY" = "unknown" ]; then
        echo "Unsupported region. Please choose from:"
        echo "EMEA: eu-west-1/2/3, eu-central-1/2, eu-south-1/2, eu-north-1"
        echo "US: us-east-1/2, us-west-1/2"
        echo "APAC: ap-east-1, ap-south-1/2, ap-northeast-1/2/3, ap-southeast-1/2/3/4"
        continue
    fi
    break
done

echo "Using AWS region: $AWS_REGION ($REGION_CITY)"

# Function to update prefix in file
update_prefix() {
    local file=$1
    if [ -f "$file" ]; then
        echo "Updating $file..."
        sed -i.bak \
            -e "s/\([a-z0-9-]*\)-aws-cml/${PREFIX}-aws-cml/g" \
            -e "s/cml-[a-z]*-\([a-z0-9-]*\)/cml-${REGION_CITY}-${PREFIX}/g" \
            "$file"
    fi
}

# Create backup directory
BACKUP_DIR="backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup and update all relevant files
echo "Creating backups in $BACKUP_DIR..."
for file in \
    config.yml \
    documentation/AWS.md \
    modules/deploy/aws/main.tf \
    modules/deploy/main.tf \
    variables.tf; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/$(basename $file).bak"
        update_prefix "$file"
    fi
done

echo "Configuration updated with prefix: $PREFIX"
echo "Backups created in: $BACKUP_DIR/"

# Store the root directory
ROOT_DIR=$(pwd)

cd modules/deploy

# Flag to track if S3 backend was requested
USE_S3_BACKEND=false

# AWS enabled by default
if ask_yes_no "Cloud - Enable AWS? (yes/no) [default: yes]" "yes"; then
    echo "Enabling AWS."
    rm aws.tf
    ln -s aws-on.t-f aws.tf
    
    # Ask about S3 backend
    if ask_yes_no "Do you want to use S3 for Terraform state backend? (yes/no) [default: no]" "no"; then
        USE_S3_BACKEND=true
        echo "Creating backend configuration..."
        mkdir -p "$ROOT_DIR/config"
        # Create backend.tf for initial setup
        cat > "$ROOT_DIR/backend.tf" <<EOF
module "backend" {
  source = "./modules/backend"
  prefix = "${PREFIX}"
  region = "${AWS_REGION:-eu-west-1}"
}

terraform {
  backend "s3" {}
}
EOF

        # Create backend config for after backend is created
        cat > "$ROOT_DIR/config/backend.hcl" <<EOF
bucket         = "${PREFIX}-aws-cml-tfstate"
key            = "terraform.tfstate"
region         = "${AWS_REGION:-eu-west-1}"
dynamodb_table = "${PREFIX}-aws-cml-tfstate-lock"
encrypt        = true
EOF
        echo "Backend configuration created in config/backend.hcl"
        echo "Backend module configuration created in backend.tf"
    fi
else
    echo "Disabling AWS."
    rm aws.tf
    ln -s aws-off.t-f aws.tf
fi

# Azure disabled by default
if ask_yes_no "Cloud - Enable Azure? (yes/no) [default: no]" "no"; then
    echo "Enabling Azure."
    rm azure.tf
    ln -s azure-on.t-f azure.tf
else
    echo "Disabling Azure."
    rm azure.tf
    ln -s azure-off.t-f azure.tf
fi

cd ../..
cd modules/secrets

# Conjur disabled by default
if ask_yes_no "External Secrets Manager - Enable CyberArk Conjur? (yes/no) [default: no]" "no"; then
    echo "Enabling CyberArk Conjur."
    rm conjur.tf || true
    ln -s conjur-on.t-f conjur.tf
else
    echo "Disabling CyberArk Conjur."
    rm conjur.tf || true
    ln -s conjur-off.t-f conjur.tf
fi

# Vault disabled by default
if ask_yes_no "External Secrets Manager - Enable Hashicorp Vault? (yes/no) [default: no]" "no"; then
    echo "Enabling Hashicorp Vault."
    rm vault.tf || true
    ln -s vault-on.t-f vault.tf
else
    echo "Disabling Hashicorp Vault."
    rm vault.tf || true
    ln -s vault-off.t-f vault.tf
fi

# Update configurations with prefix
echo "Updating configurations with prefix: $PREFIX"
sed -i.bak \
    -e "s/bucket: \([a-z0-9-]*\)-aws-cml/bucket: ${PREFIX}-aws-cml/" \
    -e "s/key_name: cml-[a-z]*-\([a-z0-9-]*\)/key_name: cml-${REGION_CITY}-${PREFIX}/" \
    -e "s/region: [a-z0-9-]*/region: ${AWS_REGION}/" \
    -e "s/availability_zone: [a-z0-9-]*/availability_zone: ${AWS_REGION}a/" \
    "$ROOT_DIR/config.yml"

cd "$ROOT_DIR"

# If S3 backend was requested, offer to run the commands
if [ "$USE_S3_BACKEND" = true ]; then
    echo "S3 backend setup requested. Would you like to initialize it now?"
    if ask_yes_no "Initialize S3 backend? (yes/no) [default: yes]" "yes"; then
        BUCKET_NAME="${PREFIX}-aws-cml-tfstate"
        TABLE_NAME="${PREFIX}-aws-cml-tfstate-lock"
        
        # Check if bucket exists
        echo "Checking for existing S3 bucket..."
        if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
            echo "Found existing S3 bucket: $BUCKET_NAME"
        else
            echo "Creating S3 backend infrastructure..."
            terraform init
            terraform apply -target=module.backend -auto-approve
        fi
        
        echo "Configuring Terraform to use S3 backend..."
        # Create backend configuration
        cat > "$ROOT_DIR/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "terraform.tfstate"
    region         = "${AWS_REGION:-eu-west-1}"
    dynamodb_table = "${TABLE_NAME}"
    encrypt        = true
  }
}

module "backend" {
  source = "./modules/backend"
  prefix = "${PREFIX}"
  region = "${AWS_REGION:-eu-west-1}"
}
EOF
        
        # Initialize with the new backend
        terraform init -migrate-state
        
        echo "S3 backend setup complete!"
    else
        echo "You can initialize the S3 backend later with:"
        echo "  # Check if bucket exists"
        echo "  aws s3api head-bucket --bucket ${PREFIX}-aws-cml-tfstate"
        echo "  # If bucket doesn't exist:"
        echo "  terraform init && terraform apply -target=module.backend -auto-approve"
        echo "  # Then initialize backend:"
        echo "  terraform init -migrate-state"
    fi
fi
