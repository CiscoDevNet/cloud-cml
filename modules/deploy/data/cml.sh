#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# set -x
# set -e


source /provision/vars.sh
source /provision/copyfile.sh


function setup_pre_aws() {
    export AWS_DEFAULT_REGION=${CFG_AWS_REGION}
    apt-get install -y awscli
}


function setup_pre_azure() {
    curl -LO https://aka.ms/downloadazcopy-v10-linux
    tar xvf down* --strip-components=1 -C /usr/local/bin
    chmod a+x /usr/local/bin/azcopy
}


function base_setup() {
    # copy Debian package from cloud storage into our instance
    copyfile ${CFG_APP_DEB} /provision/

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

    systemctl stop ssh
    apt-get install -y /provision/${CFG_APP_DEB}
    # fix for the NM on AWS
    echo "    renderer: NetworkManager" >> /etc/netplan/50-cloud-init.yaml
    sed -i 's/^unmanaged-devices=.*/unmanaged-devices=none/' /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
    service network-manager restart
    netplan apply
    #
    export HOME=/var/local/virl2
    /usr/local/bin/virl2-initial-setup.py
    #touch /etc/.virl2_unconfigured
    #systemctl enable --now virl2-initial-setup.service
    netplan apply
    systemctl enable --now ssh.service
    systemctl start ssh

    # AWS specific (?):
    # For troubleshooting. To allow console access on AWS, the root user needs a
    # password. Note: not all instance types / flavors provide a serial console!
    # echo "root:secret-password-here" | /usr/sbin/chpasswd
}


function cml_configure() {
    target=$1
    API="http://ip6-localhost:8001/api/v0"

    # Create system user
    #/usr/sbin/useradd --badname -m -s /bin/bash ${CFG_SYS_USER}
    #echo "${CFG_SYS_USER}:${CFG_SYS_PASS}" | /usr/sbin/chpasswd
    #/usr/sbin/usermod -a -G sudo ${CFG_SYS_USER}

    # Move SSH config from default cloud-provisioned user to new user. This
    # also disables the login for this user by removing the SSH key.
    # Technically, this could be the same user as Azure allows to set the
    # user name
    # if [ "$target" = "aws" ]; then
    #     clouduser="ubuntu"
    # elif [ "$target" = "azure" ]; then
    #     clouduser="adminuser"
    # else
    #     echo "unknown target"
    # fi
    clouduser="ubuntu"
    rm -rf /home/${CFG_SYS_USER}/.ssh
    mv /home/$clouduser/.ssh /home/${CFG_SYS_USER}/
    chown -R ${CFG_SYS_USER}.${CFG_SYS_USER} /home/${CFG_SYS_USER}/.ssh
    userdel -r $clouduser

    # allow this user to read the configuration vars
    chgrp ${CFG_SYS_USER} /provision/vars.sh
    chmod g+r /provision/vars.sh

    # Change the ownership of the del.sh script to the sysadmin user
    chown ${CFG_SYS_USER}.${CFG_SYS_USER} /provision/del.sh

    until [ "true" = "$(curl -s $API/system_information | jq -r .ready)" ]; do
        echo "Waiting for controller to be ready..."
        sleep 5
    done

    # Get auth token
    #PASS=$(cat /etc/machine-id)
    #TOKEN=$(echo '{"username":"cml2","password":"'$PASS'"}' \ |
    #    curl -s -d@- $API/authenticate | jq -r)
    #[ "$TOKEN" != "Authentication failed!" ] || { echo $TOKEN; exit 1; }

    # Change to provided name and password
    #curl -s -X "PATCH" \
    #    "$API/users/00000000-0000-4000-a000-000000000000" \
    #    -H "Authorization: Bearer $TOKEN" \
    #    -H "accept: application/json" \
    #    -H "Content-Type: application/json" \
    #    -d '{"username":"'${CFG_APP_USER}'","password":{"new_password":"'${CFG_APP_PASS}'","old_password":"'$PASS'"}}'

    # Re-auth with new password
    TOKEN=$(echo '{"username":"'${CFG_APP_USER}'","password":"'${CFG_APP_PASS}'"}' \ |
        curl -s -d@- $API/authenticate | jq -r)

    # This is still local, everything below talks to GCH licensing servers
    curl -s -X "PUT" \
        "$API/licensing/product_license" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d '"'${CFG_LICENSE_FLAVOR}'"'

    # We want to see what happens
    # set -x

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

        if [ "$(echo $result | jq -r '.registration.status')" = "COMPLETED" ] && [ "$(echo $result | jq -r '.authorization.status')" = "IN_COMPLIANCE" ] ; then
            break
        fi
        echo "no license, trying again ($attempts)"
        (( attempts-- ))
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
    FILELIST=$(find /provision/ -type f | egrep '[0-9]{2}-[[:alnum:]_]+\.sh' | grep -v '99-dummy' | sort)
    if [ -n "$FILELIST" ]; then
        systemctl stop virl2.target
        while [ $(systemctl is-active virl2-controller.service) = active ]; do
            sleep 5
        done
        (
            mkdir -p /var/log/provision
            echo "$FILELIST" | wc -l
            for patch in $FILELIST; do
                echo "processing $patch ..."
                (
                    source "$patch" || true
                ) 2>&1 | tee "/var/log/"$patch".log"
                echo "done with $patch"
            done
        )
        sleep 5
        # do this for good measure, best case this is a no-op
        netplan apply
        # restart the VIRL2 target now
        systemctl restart virl2.target
    fi
}


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
fi

