function backupBucketToBucket() {
  echo "Starting Backup"

  removeOldFolder

  DATE=$(date +"%d-%m-%Y")
  mc cp -r $SRC/ $DST/$DATE

  echo "Backup Done"

  exit 0
}

function removeOldFolder() {
  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  mc rm --recursive --force $DST/$DATE
}