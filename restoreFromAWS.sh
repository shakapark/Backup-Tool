secs_to_human() {
  return "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
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

  checkBackup

  echo "Postgres from $BACKUP_NAME..."

  aws --endpoint-url $S3_DESTINATION_HOST s3 cp s3://$S3_DESTINATION_BUCKET/$BACKUP_NAME - |\
   pg_restore -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE $COMPRESSION
}