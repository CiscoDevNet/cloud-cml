#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
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
    
    echo "Installing AWS CLI..."
    if ! apt-get install -y awscli; then
        echo "APT installation of AWS CLI failed, installing AWS CLI v2..."
        
        # Install required dependencies
        apt-get install -y unzip curl

        # Download and install AWS CLI v2
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
        rm -rf aws awscliv2.zip
        
        # Verify installation
        if ! aws --version; then
            echo "Error: AWS CLI installation failed"
            exit 1
        fi
        echo "AWS CLI v2 installed successfully"
    else
        echo "AWS CLI installed via APT successfully"
    fi
}

function setup_pre_azure() {
    curl -LO https://aka.ms/downloadazcopy-v10-linux
    tar xvf down* --strip-components=1 -C /usr/local/bin
    chmod a+x /usr/local/bin/azcopy
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
    echo "Copying CML package from cloud storage..."
    copyfile ${CFG_APP_SOFTWARE} /provision/
    
    echo "Extracting CML package..."
    if [ ! -f "/provision/${CFG_APP_SOFTWARE}" ]; then
        echo "Error: CML package not found at /provision/${CFG_APP_SOFTWARE}"
        exit 1
    fi

    # Create temp directory for package extraction
    TEMP_DIR=$(mktemp -d)
    tar xvf "/provision/${CFG_APP_SOFTWARE}" -C "$TEMP_DIR"
    
    # Find and install the packages
    echo "Installing CML packages..."
    DEB_FILES=$(find "$TEMP_DIR" -name "*.deb")
    if [ -z "$DEB_FILES" ]; then
        echo "Error: No .deb files found in the CML package"
        exit 1
    fi

    # Stop SSH before installation
    systemctl stop ssh || echo "Warning: Failed to stop SSH"

    # Install each package individually
    for deb in $DEB_FILES; do
        echo "Installing $deb..."
        if ! apt-get install -y "$deb"; then
            echo "Error: Failed to install $deb"
            exit 1
        fi
    done

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    echo "Running interface fix..."
    if [ -f /provision/interface_fix.py ]; then
        /provision/interface_fix.py
    else
        echo "Warning: interface_fix.py not found"
    fi

    # Check for NetworkManager
    if systemctl list-unit-files | grep -q network-manager; then
        echo "Restarting NetworkManager..."
        systemctl restart network-manager || echo "Warning: Failed to restart NetworkManager"
    else
        echo "NetworkManager not found, setting up..."
        setup_network_manager
    fi

    # Check for virl2-initial-setup service
    if [ -f /lib/systemd/system/virl2-initial-setup.service ]; then
        echo "Configuring virl2-initial-setup..."
        sed -i '/^Standard/ s/^/#/' /lib/systemd/system/virl2-initial-setup.service
        touch /etc/.virl2_unconfigured
        systemctl stop getty@tty1.service || echo "Warning: Failed to stop getty"
        echo "initial setup start: $(date +'%T.%N')"
        systemctl enable --now virl2-initial-setup.service
        echo "initial setup done: $(date +'%T.%N')"
    else
        echo "Error: virl2-initial-setup.service not found. CML installation may have failed."
        echo "Contents of /provision:"
        ls -la /provision/
        echo "Contents of /tmp:"
        ls -la /tmp/
        exit 1
    fi

    # Wait for initial setup
    attempts=5
    while [ $attempts -gt 0 ]; do
        sleep 5
        if [ ! -f /etc/.virl2_unconfigured ]; then
            echo "initial setup is done"
            break
        fi
        echo "waiting for initial setup... ($attempts attempts remaining)"
        ((attempts--))
    done

    if [ $attempts -eq 0 ]; then
        echo "Error: initial setup did not finish in time"
        exit 1
    fi

    # Apply network config and restart SSH
    netplan apply
    systemctl enable --now ssh.service

    # Clean up
    rm -f /provision/*.pkg /provision/*.deb /tmp/*.deb

    # Disable bridge setup
    if [ -f /usr/local/bin/virl2-bridge-setup.py ]; then
        /usr/local/bin/virl2-bridge-setup.py --delete
        sed -i /usr/local/bin/virl2-bridge-setup.py -e '2iexit()'
    fi

    # Remove CML netplan config
    rm -f /etc/netplan/00-cml2-base.yaml
    netplan apply

    # Skip PaTTY on computes
    if ! is_controller; then
        return 0
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
    chown -R ${CFG_SYS_USER}.${CFG_SYS_USER} /home/${CFG_SYS_USER}/.ssh

    # disable access for the user but keep it as cloud-init requires it to be
    # present, otherwise one of the final modules will fail.
    usermod --expiredate 1 --lock $clouduser

    # allow this user to read the configuration vars
    chgrp ${CFG_SYS_USER} /provision/vars.sh
    chmod g+r /provision/vars.sh

    # Change the ownership of the del.sh script to the sys<virl_username> user
    chown ${CFG_SYS_USER}.${CFG_SYS_USER} /provision/del.sh

    # Check if this device is a controller
    if ! is_controller; then
        echo "This is not a controller node. No need to install licenses."
        return 0
    fi

    until [ "true" = "$(curl -s $API/system_information | jq -r .ready)" ]; do
        echo "Waiting for controller to be ready..."
        sleep 5
    done

    # TODO: the licensing should use the PCL -- it's there, and it can do it
    # via a small Python script

    # Acquire a token
    TOKEN=$(echo '{"username":"'${CFG_APP_USER}'","password":"'${CFG_APP_PASS}'"}' \  |
        curl -s -d@- $API/authenticate | jq -r)

    # This is still local, everything below talks to GCH licensing servers
    curl -s -X "PUT" \
        "$API/licensing/product_license" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d '"'${CFG_LICENSE_FLAVOR}'"'

    # licensing, register w/ SSM and check result/compliance
    attempts=5
    while [ $attempts -gt 0 ]; do
        curl -vs -X "POST" \
            "$API/licensing/registration" \
            -H "Authorization: Bearer $TOKEN" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d '{"token":"'${CFG_LICENSE_TOKEN}'","reregister":false}'
        sleep 5
        result=$(curl -s -X "GET" \
            "$API/licensing" \
            -H "Authorization: Bearer $TOKEN" \
            -H "accept: application/json")

        if [ "$(echo $result | jq -r '.registration.status')" = "COMPLETED" ] && [ "$(echo $result | jq -r '.authorization.status')" = "IN_COMPLIANCE" ]; then
            break
        fi
        echo "no license, trying again ($attempts)"
        ((attempts--))
    done

    if [ $attempts -eq 0 ]; then
        echo "licensing failed!"
        return 1
    fi

    # No need to put in node licenses - unavailable
    if [[ ${CFG_LICENSE_FLAVOR} =~ ^CML_Personal || ${CFG_LICENSE_NODES} == 0 ]]; then
        return 0
    fi

    ID="regid.2019-10.com.cisco.CML_NODE_COUNT,1.0_2607650b-6ca8-46d5-81e5-e6688b7383c4"
    curl -vs -X "PATCH" \
        "$API/licensing/features" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d '{"'$ID'":'${CFG_LICENSE_NODES}'}'
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

echo "### Provisioning via cml.sh starts"

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
    base_setup
fi

# Only do a configure when this is not run within Packer / AMI building
if [ ! -f /tmp/PACKER_BUILD ]; then
    cml_configure ${CFG_TARGET}
    postprocess
    netplan apply
    # systemctl reboot
fi

# Check for NetworkManager
function setup_network_manager() {
    echo "Setting up NetworkManager..."
    
    # Install NetworkManager if not present
    if ! command -v NetworkManager >/dev/null 2>&1; then
        echo "Installing NetworkManager..."
        apt-get update && apt-get install -y network-manager
    fi

    # Check/Create systemd service file
    NM_SERVICE="/etc/systemd/system/network-manager.service"
    if [ ! -f "$NM_SERVICE" ]; then
        echo "Creating NetworkManager service file..."
        cat > "$NM_SERVICE" <<'EOF'
[Unit]
Description=Network Manager
Documentation=man:NetworkManager(8)
Wants=network.target
After=network-pre.target dbus.service
Before=network.target
RequiresMountsFor=/var/run/NetworkManager

[Service]
Type=dbus
BusName=org.freedesktop.NetworkManager
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/sbin/NetworkManager --no-daemon
Restart=on-failure
CapabilityBoundingSet=CAP_NET_ADMIN CAP_DAC_OVERRIDE CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SETGID CAP_SETUID CAP_SYS_MODULE CAP_AUDIT_WRITE CAP_KILL CAP_SYS_CHROOT
ProtectSystem=true
ProtectHome=true

[Install]
WantedBy=multi-user.target
Alias=dbus-org.freedesktop.NetworkManager.service
Also=NetworkManager-dispatcher.service
EOF
    fi

    # Reload systemd and start/enable NetworkManager
    echo "Configuring NetworkManager service..."
    systemctl daemon-reload
    systemctl enable network-manager
    systemctl start network-manager

    # Verify NetworkManager status
    echo "Checking NetworkManager status..."
    if ! systemctl is-active --quiet network-manager; then
        echo "Error: NetworkManager failed to start"
        systemctl status network-manager
        exit 1
    fi

    if ! systemctl is-enabled --quiet network-manager; then
        echo "Error: NetworkManager not enabled"
        exit 1
    fi

    echo "NetworkManager setup completed successfully"
}
