#!/bin/bash

exit 1000

echo "Configure aws client..."
mkdir -p /root/.aws
envsubst < "/config/aws-config.tpl" > "/root/.aws/config"
envsubst < "/config/aws-credential.tpl" > "/root/.aws/credentials"
echo "Aws client configured"

case $ACTION in

  BACKUP)
    source backupToAWS.sh

    case $SRC_TYPE in
      BucketAWS)
        backupBucketToBucket
        ;;

      Postgres)
        backupPostgresToBucket
        ;;

      AllPostgres)
        backupAllPostgresToBucket
        ;;

      Mysql)
        backupMySqlToBucket
        ;;

      Redis)
        backupRedisToBucket
        ;;

      *)
        echo "SRC_TYPE: [BucketAWS|Postgres|Mysql|Redis]"
        exit 1
    esac
    ;;
  
  RESTORE)
    source restoreFromAWS.sh
    case $DST_TYPE in
      # BucketAWS)
      #   restoreBucketFromBucket
      #   ;;

      Postgres)
        restorePostgresFromBucket
        ;;

      # Mysql)
      #   restoreMySqlFromBucket
      #   ;;

      # Redis)
      #   restoreRedisFromBucket
      #   ;;

      *)
        echo "DST_TYPE: [Postgres]"
        exit 1
    esac
    ;;
  *)
      echo "ACTION: [BACKUP|RESTORE]"

esac
