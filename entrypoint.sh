#!/bin/bash

source backupToAWS.sh

configureMinioClient
configureAWSClient

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

        Redis)
            backupRedisToBucket
            ;;
        *)
            echo "SRC_TYPE: {BucketAWS|Postgres|Mysql|Redis}"
            exit 1
esac