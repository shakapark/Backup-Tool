#!/bin/bash

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

      FileSystem)
        backupFileSystemToBucket
        ;;

      *)
        echo "SRC_TYPE: [BucketAWS|Postgres|Mysql|Redis|FileSystem]"
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

      FileSystem)
        restoreFileSystemToBucket
        ;;

      *)
        echo "DST_TYPE: [Postgres|FileSystem]"
        exit 1
    esac
    ;;

  *)
      echo "ACTION: [BACKUP|RESTORE]"
      exit 1

esac