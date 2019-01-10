function backupBucketToBucket() {
  echo "Starting Backup AWS Bucket"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/bucket-$DATE

  DATE=$(date +"%d-%m-%Y")
  mc cp -r $SRC/ $DST/bucket-$DATE

  echo "Backup Done"

  exit 0
}

function backupPostgresToBucket() {
  echo "Starting Backup Postgres"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/postgres-$DATE

  DATE=$(date +"%d-%m-%Y")
  FILE=backup-$POSTGRES_DATABASE-$DATE.sql

  PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE > $FILE
  mc cp $FILE $DST/postgres-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}

function backupMySqlToBucket() {
  echo "Starting Backup Mysql"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/mysql-$DATE

  DATE=$(date +"%d-%m-%Y")
  FILE=backup-$MYSQL_DATABASE-$DATE.sql

  mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD --databases $MYSQL_DATABASE > $FILE
  mc cp $FILE $DST/mysql-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}

function backupRedisToBucket() {
  echo "Starting Backup Redis"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/redis-$DATE

  DATE=$(date +"%d-%m-%Y")
  
  FILE=backup-redis-$DATE.sql

  python PythonScripts/redis_backup.py -backup_dir=./ -backup_filename=$FILE -redis_host=$REDIS_HOST -redis_port=$REDIS_PORT
  mc cp $FILE $DST/redis-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}