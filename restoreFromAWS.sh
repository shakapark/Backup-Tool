secs_to_human() {
  DIFF_TIME=`expr $1 - $2`
  echo  "$(( ${DIFF_TIME} / 3600 ))h $(( (${DIFF_TIME} / 60) % 60 ))m $(( ${DIFF_TIME} % 60 ))s"
}

# function convertDate() {
#   # get %d-%m-%Y
#   return echo $1 | awk -F'-' '{print $3"-"$2"-"$1}'
#   # return '%Y-%m-%d'
# }

# function getLastBackup() {
#   BACKUP_DAYS=aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_SOURCE_BUCKET |\
#                grep 'postgres-' | awk -F'postgres-' '{print $2}' | awk -F'/' '{print $1}'
#   echo $BACKUP_DAYS

#   MOST_RECENT_DAY=$(date --date='@0')
#   for day in BACKUP_DAYS; do
#     echo $day
#     day2=convertDate $day
#     echo $day2
#     if (compareDate $MOST_RECENT_DAY $day2); then
#       $MOST_RECENT_DAY=$day2
#     fi
#   done
#   echo $MOST_RECENT_DAY
#   return "postgres-$MOST_RECENT_DAY"
# }

function checkBackup() {
  aws --endpoint-url $S3_DESTINATION_HOST s3 ls --summarize --human-readable s3://$S3_DESTINATION_BUCKET/$BACKUP_NAME
}

function restorePostgresFromBucket() {
  # BACKUP=getLastBackup

  if [ "$COMPRESSION_ENABLE" = "true" ]; then
    echo "Enable compression"
    COMPRESSION="-Fc"
  else
    echo "Disable compression"
    COMPRESSION=""
  fi

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    echo "Enabling encryption"
    ENCRYPTION="openssl smime -decrypt -binary -inform DEM -inkey $BACKUP_PRIVATE_KEY | \\"
  else
    echo "Disabling encryption"
    ENCRYPTION=""
  fi

  set -e

  checkBackup

  echo "Restore from $BACKUP_NAME..."
  DATE_BEGIN=`date +%s`

  aws --endpoint-url $S3_DESTINATION_HOST s3 cp s3://$S3_DESTINATION_BUCKET/$BACKUP_NAME - |\
    eval ${ENCRYPTION}
    PGPASSWORD=$POSTGRES_PASSWD pg_restore -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE \
    --no-owner $COMPRESSION

  DATE_ENDING=`date +%s`
  echo "Restore Done"

  TIME=$(secs_to_human $DATE_ENDING $DATE_BEGIN)
  echo "Resume:"
  echo "  Total time: $TIME"
}
