#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

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
