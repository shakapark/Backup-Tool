function configureMinioClient() {
  mkdir -p /root/.mc
  envsubst < "/config/minio-config.tpl" > "/root/.mc/config.json"
}
function configureAWSClient() {
  mkdir -p /root/.aws
  envsubst < "/config/aws-config.tpl" > "/root/.aws/config"
  envsubst < "/config/aws-credential.tpl" > "/root/.aws/credentials"
}

function backupBucketToBucket() {
  echo "Starting Backup AWS Bucket"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/bucket-$DATE

  set -e

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

  set -e

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$POSTGRES_DATABASE-$DATEHOUR.sql

  PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE | \
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$DST/postgres-$DATE/$FILE

  echo "Backup Done"
}

function backupMySqlToBucket() {
  echo "Starting Backup Mysql"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/mysql-$DATE

  set -e

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$MYSQL_DATABASE-$DATEHOUR.sql

  mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD --databases $MYSQL_DATABASE | \
  aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$DST/mysql-$DATE/$FILE

  echo "Backup Done"
}

function backupRedisToBucket() {
  echo "Starting Backup Redis"

  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/redis-$DATE

  set -e

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-redis-$DATEHOUR.rdb

  python3 PythonScripts/redis_backup.py dump -o $FILE --host=$REDIS_HOST --port=$REDIS_PORT
  mc cp $FILE $DST/redis-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
  sleep 600
}