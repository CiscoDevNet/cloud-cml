#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#
CONFIG_FILE="/etc/virl2-base-config.yml"

function is_controller() {
    [[ -r "$CONFIG_FILE" ]] && grep -qi "is_controller: true" "$CONFIG_FILE"
}
