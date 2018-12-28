#!/bin/bash

source backupToAWS.sh

case $SRC_TYPE in
        BucketAWS)
            backupBucketToBucket
            ;;

        Postgres)
            backupPostgresToBucket
            ;;

        *)
            echo "SRC_TYPE: {BucketAWS|Postgres}"
            exit 1
esac