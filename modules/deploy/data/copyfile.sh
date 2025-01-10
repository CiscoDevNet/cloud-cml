#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

source /provision/vars.sh

function copyfile() {
    SRC=$1
    DST=$2
    ITEM=$3
    RECURSIVE=$4
    case $CFG_TARGET in
        aws)
            if [ -n "$ITEM" ]; then
                ITEM="/$ITEM"
            fi
            aws s3 cp --no-progress $RECURSIVE "s3://$CFG_AWS_BUCKET/$SRC" $DST$ITEM
            ;;
        azure)
            LOC="https://${CFG_AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${CFG_AZURE_CONTAINER_NAME}"
            azcopy copy --output-level=quiet "$LOC/$SRC$CFG_SAS_TOKEN" $DST $RECURSIVE
            ;;
        *) ;;
    esac
}
