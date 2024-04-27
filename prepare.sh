#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

cd $(dirname $0)

ask_yes_no() {
    while true; do
        read -p "$1 (yes/no): " answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
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

cd modules/deploy
if ask_yes_no "Enable AWS"; then
    echo "Enabling AWS"
    rm aws.tf
    ln -s aws-on.t-f aws.tf
else
    echo "Disabling AWS"
    rm aws.tf
    ln -s aws-off.t-f aws.tf
fi
if ask_yes_no "Enable Azure"; then
    echo "Enabling Azure"
    rm azure.tf
    ln -s azure-on.t-f azure.tf
else
    echo "Disabling Azure"
    rm azure.tf
    ln -s azure-off.t-f azure.tf
fi
if ask_yes_no "Enable Google Cloud Platform"; then
    echo "Enabling Google Cloud Platform"
    rm gcp.tf
    ln -s gcp-on.t-f gcp.tf
else
    echo "Disabling Google Cloud Platform"
    rm gcp.tf
    ln -s gcp-off.t-f gcp.tf
fi
cd ../..
cd modules/secrets
if ask_yes_no "Enable Conjur"; then
    echo "Enabling Conjur"
    rm conjur.tf || true
    ln -s conjur-on.t-f conjur.tf
else
    echo "Disabling Conjur"
    rm conjur.tf || true
    ln -s conjur-off.t-f conjur.tf
fi
if ask_yes_no "Enable Vault"; then
    echo "Enabling Vault"
    rm vault.tf || true
    ln -s vault-on.t-f vault.tf
else
    echo "Disabling Vault"
    rm vault.tf || true
    ln -s vault-off.t-f vault.tf
fi
