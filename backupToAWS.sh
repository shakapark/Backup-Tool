function backupBucketToBucket() {
  echo "Starting Backup"

  removeOldFolder

  DATE=$(date +"%d-%m-%Y")
  mc cp -r $SRC/ $DST/$DATE

  echo "Backup Done"

  exit 0
}

function backupPostgresToBucket() {
  echo "Starting Backup"

  removeOldFolder

  DATE=$(date +"%d-%m-%Y")
  FILE=backup-$POSTGRES_DATABASE-$DATE.sql

  PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE > $FILE
  mc cp $FILE $DST/$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}

function removeOldFolder() {
  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/$DATE
}