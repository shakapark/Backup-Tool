#!/bin/bash

source backupToAWS.sh

case $SRC_TYPE in
        BucketAWS)
            backupBucketToBucket
            ;;

        *)
            echo "SRC_TYPE: {BucketAWS}"
            exit 1
esac