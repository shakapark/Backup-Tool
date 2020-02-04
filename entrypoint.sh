#!/bin/bash

case $DST_TYPE in

    BucketAWS)

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

                Redis)
                    backupRedisToBucket
                    ;;
                *)
                    echo "SRC_TYPE: {BucketAWS|Postgres|Mysql|Redis}"
                    exit 1
        esac

    BlobAzure)

        source backupToBlob.sh

        case $SRC_TYPE in
                BucketAWS)
                    backupBucketToBlob
                    ;;

                Postgres)
                    backupPostgresToBlob
                    ;;

                Mysql)
                    backupMySqlToBlob
                    ;;

                Redis)
                    backupRedisToBlob
                    ;;
                *)
                    echo "SRC_TYPE: {BucketAWS|Postgres|Mysql|Redis}"
                    exit 1
        esac

    *)
        echo "DST_TYPE: {BucketAWS|BlobAzure}"
        exit 1
esac