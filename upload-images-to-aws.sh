#!/bin/bash

#
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#
# This script can be installed on an on-prem CML controller which also has the
# required reference platform images and definitions.
#
# In addition to standard tools already installed on the controller, the AWS CLI
# utility must be installed and configured. For configuration, the access key
# and secret must be known. Then, run "aws configure" to provide these.
#
# Alternatively, they can be provided via environment variables:
# AWS_ACCESS_KEY_ID=ABCD AWS_SECRET_ACCESS_KEY=EF1234 aws ec2 describe-instances
#

DEFAULT_BUCKET="aws-cml-images"

BUCKETNAME=${1:-$DEFAULT_BUCKET}
ISO=${2:-/var/lib/libvirt/images}
PKG=${3:-cml2_*.pkg}

function help() {
    cmd=$(basename $0)
    cat <<EOF
CML2 S3 bucket upload helper script

Usage: $cmd [bucketname] [reference platform directory] [PKG wildcard]

For this to work, the dialog and the AWS CLI tool need to be installed.
The AWS CLI tool must also be configured with a valid access and secret key
(via 'aws configure').

If a CML software .pkg package is located in the current directory, then
the tool can upload it to the bucket, too.

defaults:
- bucketname = $DEFAULT_BUCKET
- directory = $ISO
- software pkg wildard = $PKG
EOF
}

if [[ "$1" =~ (--)?help|-h ]]; then
    help
    exit
fi

if [ -z "$(which aws)" ]; then
    echo "AWS CLI tool required but not present in path!"
    echo "see https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    echo "or install it via 'apt install awscli'"
    exit 255
fi

if [ -z "$(which dialog)" ]; then
    echo "dialog utility required but not present in path!"
    echo "install it via 'apt install dialog'"
    exit 255
fi

if [ ! -d $ISO ]; then 
    echo "Provided reference platform path \"$ISO\" does not exist!"
    exit 255
fi

cd $ISO
if [ ! -d virl-base-images -a ! -d node-definitions ]; then
    echo "Provided path \"$ISO\" has no CML node / image definitions!"
    exit 255
fi

function ctrlc() {
    echo
    echo "Ctrl-C detected -- exiting!"
    exit 1
}

trap ctrlc SIGINT

cmlpkg=$(find . -name "$PKG" | sort | tail -1)
if [ -n "$cmlpkg" ]; then
    echo $cmlpkg
    if ! dialog --title "Software PKG found, copy to Bucket?" \
        --defaultno --yesno \
        "$(basename $cmlpkg)" 5 40; then
        # if no is selected...
        cmlpkg=""
    fi
fi

pushd &>/dev/null virl-base-images
options=$(find . -name '*.yaml' -exec sh -c 'basename '{}'; echo "on"' \; )
popd &>/dev/null

if [ -z "$options" ]; then
    echo "there's apparently no images in the directory specified ($ISO)"
    echo "please ensure that there's at least one image and node definition"
    exit 255
fi

selection=$(dialog --stdout --no-items --separate-output --checklist \
    "Select images to copy to AWS bucket \"${BUCKETNAME}\"" 0 60 20 $options \
)
s=$?
clear
if [ $s -eq 255 ]; then
    echo "reference platform image upload aborted..."
    exit 255
fi

declare -A nodedefs
for imagedef in $selection; do
    fullpath=$(find $ISO -name $imagedef)
    defname=$(sed -nE '/^node_definition/s/^.*:(\s+)?(\S+)$/\2/p' $fullpath)
    nodedefs[$defname]="1"
done

if [ -n "$cmlpkg" ]; then
    dialog --progressbox "Upload software package to bucket" 20 70 < <(
        tmpdir=$(mktemp --directory)
        pushd $tmpdir
        tar xf $cmlpkg --wildcards 'cml2_*.deb'
        aws s3 cp *.deb s3://${BUCKETNAME}/
        rm cml2_*.deb
        popd
        rmdir $tmpdir
    )
fi

target="s3://${BUCKETNAME}/refplat"

dialog --progressbox "Upload node definitions to bucket" 20 70 < <(
    for nodedef in ${!nodedefs[@]}; do
        fname=$(grep -l $ISO/node-definitions/* -Ee "^id:(\s+)?${nodedef}$")
        aws s3 cp $fname $target/node-definitions/
        s=$?
        if [ $s -ne 0 ]; then
            clear
            echo "An error occured during node definition upload, exiting..."
            exit 255
        fi
    done
)

dialog --progressbox "Upload images to bucket" 20 70 < <(
    for imagedef in $selection; do
        imagedir=$(find $ISO -name $imagedef | xargs dirname)
        # https://www.linuxjournal.com/article/8919
        # ${imagedir <-- from variable imagedir
        #   ##       <-- greedy front trim
        #   *        <-- matches anything
        #   /        <-- until the last '/'
        # }
        aws s3 cp --recursive $imagedir $target/virl-base-images/${imagedir##*/}
        s=$?
        if [ $s -ne 0 ]; then
            clear
            echo "An error occured during image upload, exiting..."
            exit 255
        fi
    done
)

clear
echo "done!"
