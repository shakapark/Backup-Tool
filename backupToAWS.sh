secs_to_human() {
  DIFF_TIME=`expr $1 - $2`
  echo "$(( ${DIFF_TIME} / 3600 ))h $(( (${DIFF_TIME} / 60) % 60 ))m $(( ${DIFF_TIME} % 60 ))s"
}

function check_last_backup() {
  set +e

  echo "Begin Check"
  OLD_BACKUPS=`aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_DESTINATION_BUCKET/ --exclude "$1" --include "*.done"`# | grep -v $1 | grep .done`
  echo $OLD_BACKUPS
  if [ -z "$OLD_BACKUPS" ]; then
    echo "No old backup found"
    exit 0
  fi

  echo "Backups found:"
  # echo "$OLD_BACKUPS"

  # old_backups=`echo $OLD_BACKUPS | awk -F'\n' '{ s = $1; for (i = 2; i <= NF; i++) s = s "\n"$i; print s; }'`
  for backup in $OLD_BACKUPS; do
    echo $backup
    # echo "test split"
    # split=`echo $backup | awk -F '-' '{ s = $1; for (i = 2; i <= NF; i++) s = s "\n"$i; print s; }'`
    # echo $split
  done
}

function backupBucketToBucket() {
  echo "Starting Backup AWS Bucket"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/bucket-$DATE

  set -e

  DATE=$(date +"%d-%m-%Y")

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  aws --endpoint-url $S3_DESTINATION_HOST s3 cp --recursive s3://$S3_SOURCE_BUCKET s3://$S3_DESTINATION_BUCKET/bucket-$DATE

  DATE_ENDING=`date +%s`
  echo "Backup Done"

  echo "Resume:"
  echo "  Total time: `expr $DATE_ENDING - $DATE_BEGIN`"
}

function backupPostgresToBucket() {
  echo "Starting Backup Postgres"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_SOURCE_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/postgres-$DATE

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$POSTGRES_DATABASE-$DATEHOUR

  DAY_BACKUP=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done)
  # echo $DAY_BACKUP
  if [ -n "$DAY_BACKUP" ]; then
    echo "Backup already exist. Exit..."
    exit 0
  fi

  set -e

  if [ -z "$POSTGRES_TABLE" ];then
    FILTER_TABLE=""
  else
    list_table=`echo $POSTGRES_TABLE | awk -F ',' '{ s = $1; for (i = 2; i <= NF; i++) s = s "\n"$i; print s; }'`
    for table in ${list_table}
    do
      FILTER_TABLE+="-t $table "
    done
    FILE+="-tables=$POSTGRES_TABLE"
  fi

  if [ -z "$POSTGRES_EXCLUDE_TABLE" ];then
    EXCLUDE_TABLE=""
  else
    list_exclude_table=`echo $POSTGRES_EXCLUDE_TABLE | awk -F ',' '{ s = $1; for (i = 2; i <= NF; i++) s = s "\n"$i; print s; }'`
    for table in ${list_exclude_table}
    do
      EXCLUDE_TABLE+="-T $table "
    done
    FILE+="-excludetables=$POSTGRES_EXCLUDE_TABLE"
  fi

  if [ "$COMPRESSION_ENABLE" = "true" ]; then
    echo "Enable compression"
    COMPRESSION="-Fc"
  else
    echo "Disable compression"
    COMPRESSION=""
  fi

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE \
  $FILTER_TABLE $EXCLUDE_TABLE $COMPRESSION | \
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql

  DATE_ENDING=`date +%s`
  echo "Backup Done"

  SIZE=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls --summarize --human-readable s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql | grep "Total Size" | awk -F': ' '{print $2}')
  TIME=$(secs_to_human $DATE_ENDING $DATE_BEGIN)

  echo "Resume:"
  echo "  File name: postgres-$DATE/$FILE.sql"
  echo "  Dump size: $SIZE"
  echo "  Total time: $TIME"

  echo "Resume:" > postgres-$DATE.done
  echo "  File name: postgres-$DATE/$FILE.sql" >> postgres-$DATE.done
  echo "  Dump size: $SIZE" >> postgres-$DATE.done
  echo "  Total time: $TIME" >> postgres-$DATE.done
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp postgres-$DATE.done s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done
  # cat postgres-$DATE.done
  rm postgres-$DATE.done
  check_last_backup "postgres-$DATE.done"
}

function backupMySqlToBucket() {
  echo "Starting Backup Mysql"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/mysql-$DATE

  set -e

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$MYSQL_DATABASE-$DATEHOUR.sql

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD --databases $MYSQL_DATABASE | \
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/mysql-$DATE/$FILE

  DATE_ENDING=`date +%s`
  echo "Backup Done"

  SIZE=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls --summarize --human-readable s3://$S3_DESTINATION_BUCKET/mysql-$DATE/$FILE | grep "Total Size" | awk -F': ' '{print $2}')
  TIME=$(secs_to_human $DATE_ENDING $DATE_BEGIN)
  echo "Resume:"
  echo "  Dump size: $SIZE"
  echo "  Total time: $TIME"
}

function backupRedisToBucket() {
  echo "Starting Backup Redis"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/redis-$DATE

  set -e

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-redis-$DATEHOUR.rdb

  python3 PythonScripts/redis_backup.py dump -o $FILE --host=$REDIS_HOST --port=$REDIS_PORT
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp $FILE s3://$S3_DESTINATION_BUCKET/redis-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}