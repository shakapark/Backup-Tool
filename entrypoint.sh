#!/bin/bash

source backupToAWS.sh

case $SRC_TYPE in
        BucketAWS)
            backupBucketToBucket
            ;;

        Postgres)
            backupPostgresToBucket
            ;;

        Mysql)
            backupMySqlToBucket
            ;;

        *)
            echo "SRC_TYPE: {BucketAWS|Postgres|Mysql}"
            exit 1
esac