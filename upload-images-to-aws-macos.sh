#!/bin/bash

#
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#
# macOS-optimized version of the CML image upload script
#

# Default settings
BUCKETNAME=${1:-$DEFAULT_BUCKET}
# ISO variable may need to be adjusted to reflect where the image have been extracted to
ISO=${2:-/var/lib/libvirt/images}
PKG=${3:-cml2_*.pkg}

function help() {
    cmd=$(basename "$0")
    cat <<EOF
CML2 S3 bucket upload helper script (macOS version)

Usage: $cmd [bucketname] [reference platform directory] [PKG wildcard]

Requirements:
- AWS CLI (brew install awscli)
- dialog (brew install dialog)
- AWS credentials configured (aws configure)

The script will upload:
1. CML software package (if found)
2. Selected node definitions
3. Selected image definitions

Defaults:
- bucketname = $DEFAULT_BUCKET
- directory = $ISO
- software pkg wildcard = $PKG
EOF
}

# Help handling
if [[ "$1" =~ (--)?help|-h ]]; then
    help
    exit 0
fi

# Check for required tools
for tool in aws dialog; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: $tool is required but not installed"
        echo "Install using: brew install $tool"
        exit 1
    fi
done

# Validate AWS CLI configuration
if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS CLI not configured. Please run 'aws configure' first"
    exit 1
fi

# Check if bucket exists and is accessible
if ! aws s3 ls "s3://${BUCKETNAME}" &>/dev/null; then
    echo "Error: Cannot access bucket s3://${BUCKETNAME}"
    echo "Please check bucket name and AWS permissions"
    exit 1
fi

# Validate image directory
if [ ! -d "$ISO" ]; then 
    echo "Error: Reference platform path \"$ISO\" does not exist!"
    exit 1
fi

# Change to image directory
cd "$ISO" || exit 1

# Validate directory structure
if [ ! -d "virl-base-images" ] || [ ! -d "node-definitions" ]; then
    echo "Error: \"$ISO\" missing required directories (virl-base-images or node-definitions)"
    exit 1
fi

# CTRL+C handler
trap 'echo -e "\nOperation cancelled"; exit 1' INT

# Look for CML package
cmlpkg=$(find . -name "$PKG" -type f | sort | tail -1)
if [ -n "$cmlpkg" ]; then
    if ! dialog --title "Software PKG found, copy to Bucket?" \
        --defaultno --yesno \
        "$(basename "$cmlpkg")" 5 40; then
        cmlpkg=""
    fi
fi

# Build list of available images
pushd "virl-base-images" &>/dev/null || exit 1
options=$(find . -type f -name '*.yaml' -exec sh -c 'basename "{}"; echo "on"' \;)
popd &>/dev/null || exit 1

if [ -z "$options" ]; then
    echo "Error: No image definitions found in $ISO/virl-base-images"
    exit 1
fi

# Image selection dialog
selection=$(dialog --stdout --no-items --separate-output --checklist \
    "Select images to copy to AWS bucket \"${BUCKETNAME}\"" 0 60 20 $options)
dialog_status=$?
clear

if [ $dialog_status -eq 255 ]; then
    echo "Upload cancelled by user"
    exit 1
fi

# Process node definitions
declare -a nodedefs_keys
declare -a nodedefs_values
for imagedef in $selection; do
    fullpath=$(find "$ISO" -name "$imagedef")
    defname=$(sed -nE '/^node_definition/s/^.*:(\s+)?(\S+)$/\2/p' "$fullpath")
    nodedefs_keys+=("$defname")
    nodedefs_values+=("1")
done

# Upload CML package if selected
if [ -n "$cmlpkg" ]; then
    dialog --progressbox "Upload software package to bucket" 20 70 < <(
        aws s3 cp "$cmlpkg" "s3://${BUCKETNAME}/"
    )
fi

target="s3://${BUCKETNAME}/refplat"

# Upload node definitions
dialog --progressbox "Upload node definitions to bucket" 20 70 < <(
    for nodedef in "${nodedefs_keys[@]}"; do
        fname=$(grep -l "$ISO/node-definitions/"* -Ee "^id:(\s+)?${nodedef}$")
        if [ -n "$fname" ]; then
            aws s3 cp "$fname" "$target/node-definitions/"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to upload node definition: $nodedef"
                exit 1
            fi
        fi
    done
)

# Upload image definitions and files
dialog --progressbox "Upload images to bucket" 20 70 < <(
    for imagedef in $selection; do
        imagedir=$(find "$ISO" -name "$imagedef" -exec dirname {} \;)
        if [ -n "$imagedir" ]; then
            aws s3 cp --recursive "$imagedir" "$target/virl-base-images/${imagedir##*/}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to upload image: $imagedef"
                exit 1
            fi
        fi
    done
)

clear
echo "Upload completed successfully!"
echo "Bucket: s3://${BUCKETNAME}/refplat"
echo "Uploaded node definitions: ${#nodedefs_keys[@]}"
echo "Uploaded images: $(echo "$selection" | wc -l)" 