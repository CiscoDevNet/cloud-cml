#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#
# :%!shfmt -ci -i 4 -
# set -x
# set -e

source /provision/common.sh
source /provision/copyfile.sh
source /provision/vars.sh

function setup_pre_aws() {
    export AWS_DEFAULT_REGION=${CFG_AWS_REGION}
    apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -f awscliv2.zip
    rm -rf aws/
}

function setup_pre_azure() {
    curl -LO https://aka.ms/downloadazcopy-v10-linux
    tar xvf down* --strip-components=1 -C /usr/local/bin
    chmod a+x /usr/local/bin/azcopy
}

function wait_for_network_manager() {
    counter=0
    max_wait=60

    while ! systemctl is-active --quiet NetworkManager && [ $counter -lt $max_wait ]; do
        echo "Waiting for NetworkManager to become active..."
        sleep 5
        counter=$((counter + 5))
    done

    if systemctl is-active --quiet NetworkManager; then
        echo "NetworkManager is active."
    else
        echo "NetworkManager did not become active after $max_wait seconds."
    fi
}

function base_setup() {

    # Check if this device is a controller
    if is_controller; then
        # copy node definitions and images to the instance
        VLLI=/var/lib/libvirt/images
        NDEF=node-definitions
        IDEF=virl-base-images
        mkdir -p $VLLI/$NDEF

        # copy all node definitions as defined in the provisioned config
        if [ $(jq </provision/refplat '.definitions|length') -gt 0 ]; then
            elems=$(jq </provision/refplat -rc '.definitions|join(" ")')
            for item in $elems; do
                copyfile refplat/$NDEF/$item.yaml $VLLI/$NDEF/
            done
        fi

        # copy all image definitions as defined in the provisioned config
        if [ $(jq </provision/refplat '.images|length') -gt 0 ]; then
            elems=$(jq </provision/refplat -rc '.images|join(" ")')
            for item in $elems; do
                mkdir -p $VLLI/$IDEF/$item
                copyfile refplat/$IDEF/$item/ $VLLI/$IDEF $item --recursive
            done
        fi

        # if there's no images at this point, copy what's available in the defined
        # cloud storage container
        if [ $(find $VLLI -type f | wc -l) -eq 0 ]; then
            copyfile refplat/ $VLLI/ "" --recursive
        fi
    fi

    # copy CML distribution package from cloud storage into our instance, unpack & install
    copyfile ${CFG_APP_SOFTWARE} /provision/
    tar xvf /provision/${CFG_APP_SOFTWARE} --wildcards -C /tmp 'cml2*_amd64.deb' 'patty*_amd64.deb' 'iol-tools*_amd64.deb'
    systemctl stop ssh

    # install i386 architecture if the version requires it
    # Package is not installed at this point in time
    # version=$(dpkg-query --showformat='${Version}' --show cml2)
    version=$(ls /tmp/cml2_*_amd64.deb | awk -F_ '{print $2}')
    if dpkg --compare-versions "$version" ge 2.7.0; then
        dpkg --add-architecture i386
        apt-get update
    fi

    # install packages (and NetworkManager, just to be sure it's there)
    apt-get install -y network-manager /tmp/*.deb

    # Fixing NetworkManager in netplan, and interface association in virl2-base-config.yml
    /provision/interface_fix.py
    systemctl restart NetworkManager
    netplan apply
    wait_for_network_manager
    # Fix for the headless setup (tty remove as the cloud VM has none)
    sed -i '/^Standard/ s/^/#/' /lib/systemd/system/virl2-initial-setup.service
    touch /etc/.virl2_unconfigured
    systemctl stop getty@tty1.service
    echo "initial setup start: $(date +'%T.%N')"
    systemctl enable --now virl2-initial-setup.service
    echo "initial setup done: $(date +'%T.%N')"

    # this should not be needed in cloud!?
    # systemctl start getty@tty1.service

    # We need to wait until the initial setup is done
    attempts=5
    while [ $attempts -gt 0 ]; do
        sleep 5
        # substate=$(systemctl show --property=SubState --value virl2-initial-setup.service)
        # if [ "$substate" = "exited" ]; then
        if [ ! -f /etc/.virl2_unconfigured ]; then
            echo "initial setup is done"
            break
        fi
        echo "waiting for initial setup..."
        ((attempts--))
    done

    if [ $attempts -eq 0 ]; then
        echo "initial setup did not finish in time... something went wrong!"
        exit 1
    fi

    systemctl enable --now ssh.service
    wait_for_network_manager

    # clean up software .pkg / .deb packages
    rm -f /provision/*.pkg /provision/*.deb /tmp/*.deb

    # disable bridge setup in the cloud instance (controller and computes)
    # (this is a no-op with 2.7.1 as it skips bridge creation entirely)
    /usr/local/bin/virl2-bridge-setup.py --delete
    sed -i /usr/local/bin/virl2-bridge-setup.py -e '2iexit()'
    # remove the CML specific netplan config
    find /etc/netplan/ -maxdepth 1 -type f -name '*.yaml' ! -name '50-cloud-init.yaml' -exec rm -f {} +
    # apply to ensure gateway selection below works
    netplan apply
    wait_for_network_manager

    # no PaTTY on computes
    if ! is_controller; then
        return 0
    fi

    # enable and configure PaTTY
    if [ "${CFG_COMMON_ENABLE_PATTY}" = "true" ]; then
        sleep 5 # wait for ip address acquisition
        GWDEV=$(ip -json route | jq -r '.[]|select(.dst=="default")|(.metric|tostring)+"\t"+.dev' | sort | head -1 | cut -f2)
        echo "OPTS=\"-bridge $GWDEV -poll 5\"" >>/etc/default/patty.env
        sed -i '/^After/iWants=virl2-patty.service' /lib/systemd/system/virl2.target
        systemctl daemon-reload
        systemctl enable --now virl2-patty
    fi
}

function cml_configure() {
    API="http://ip6-localhost:8001/api/v0"

    clouduser="ubuntu"
    if [[ -d /home/${CFG_SYS_USER}/.ssh ]]; then
        # Directory exists - Move individual files within .ssh
        mv /home/$clouduser/.ssh/* /home/${CFG_SYS_USER}/.ssh/
    else
        # Directory doesn't exist - Move the entire .ssh directory
        mv /home/$clouduser/.ssh/ /home/${CFG_SYS_USER}/
    fi
    chown -R ${CFG_SYS_USER}:${CFG_SYS_USER} /home/${CFG_SYS_USER}/.ssh

    # disable access for the user but keep it as cloud-init requires it to be
    # present, otherwise one of the final modules will fail.
    usermod --expiredate 1 --lock $clouduser

    # allow this user to read the configuration vars
    chgrp ${CFG_SYS_USER} /provision/vars.sh
    chmod g+r /provision/vars.sh

    # Change the ownership of the del.sh script to the sysadmin user
    chown ${CFG_SYS_USER}:${CFG_SYS_USER} /provision/del.sh

    # Check if this device is a controller
    if ! is_controller; then
        echo "This is not a controller node. No need to install licenses."
        return 0
    fi

    until [ "true" = "$(curl -s $API/system_information | jq -r .ready)" ]; do
        echo "Waiting for controller to be ready..."
        sleep 5
    done

    # Put the license and users in place
    export CFG_APP_USER CFG_APP_PASS CFG_LICENSE_NODE CFG_LICENSE_FLAVOR CFG_LICENSE_TOKEN
    HOME=/var/local/virl2 python3 /provision/license.py
}

function postprocess() {
    FILELIST=$(find /provision/ -type f | grep -E '[0-9]{2}-[[:alnum:]_]+\.sh' | grep -v '99-dummy' | sort)
    if [ -n "$FILELIST" ]; then
        (
            mkdir -p /var/log/provision
            for patch in $FILELIST; do
                echo "processing $patch ..."
                (
                    source "$patch" || true
                ) 2>&1 | tee "/var/log/${patch}.log"
                echo "done with ${patch}"
            done
        )
    fi
}

echo "### Provisioning via cml.sh STARTS $(date)"

# AWS specific (?):
# For troubleshooting. To allow console access on AWS, the root user needs a
# password. Note: not all instance types / flavors provide a serial console!
# echo "root:secret-password-here" | /usr/sbin/chpasswd

# Ensure non-interactive Debian package installation
APT_OPTS="-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew"
APT_OPTS+=" -o DPkg::Progress-Fancy=0 -o APT::Color=0"
DEBIAN_FRONTEND=noninteractive
export APT_OPTS DEBIAN_FRONTEND

# Run the appropriate pre-setup function
case $CFG_TARGET in
    aws)
        setup_pre_aws
        ;;
    azure)
        setup_pre_azure
        ;;
    *)
        echo "unknown target!"
        exit 1
        ;;
esac

# Only run the base setup when there's a provision directory both with
# Terraform and with Packer but not when deploying an AMI
if [ -d /provision ]; then
    echo "### base setup STARTS $(date)"
    base_setup
fi

# Only do a configure when this is not run within Packer / AMI building
if [ ! -f /tmp/PACKER_BUILD ]; then
    echo "### configure STARTS $(date)"
    cml_configure ${CFG_TARGET}
    echo "### postprocess STARTS $(date)"
    postprocess
    # netplan apply
    # systemctl reboot
fi

echo "### Provisioning via cml.sh ENDS $(date)"
