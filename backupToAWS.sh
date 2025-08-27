secs_to_human() {
  DIFF_TIME=`expr $1 - $2`
  echo "$(( ${DIFF_TIME} / 3600 ))h $(( (${DIFF_TIME} / 60) % 60 ))m $(( ${DIFF_TIME} % 60 ))s"
}

function check_last_backup() {
  set -e

  # echo "Begin Check"
  OLD_BACKUPS=`aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_DESTINATION_BUCKET/ | awk '{print $4}' | grep -v $2 | grep $1 | grep .done`
  # echo $OLD_BACKUPS
  if [[ -z "$OLD_BACKUPS" ]]; then
    echo "No old backup found"
    exit 0
  fi

  last_year=0
  last_month=0
  last_day=0

  # echo "Backups found:"
  for backup in $OLD_BACKUPS; do
    # echo $backup
    # echo "Last backup date: $last_day-$last_month-$last_year"
    kind=`echo $backup | cut -d'.' -f1 | awk '{split($0,a,"-"); print a[1]}'`
    day=`echo $backup | cut -d'.' -f1 | awk '{split($0,a,"-"); print a[2]}'`
    month=`echo $backup | cut -d'.' -f1 | awk '{split($0,a,"-"); print a[3]}'`
    year=`echo $backup | cut -d'.' -f1 | awk '{split($0,a,"-"); print a[4]}'`
    # echo "Kind: $kind"
    # echo "Day: $day"
    # echo "Month: $month"
    # echo "Year: $year"

    if [ $year -gt $last_year ]; then
      last_year=$year
      last_month=$month
      last_day=$day
    elif [ $year -eq $last_year ]; then
      if [ $month -gt $last_month ]; then
        last_month=$month
        last_day=$day
      elif [ $month -eq $last_month ]; then
        if [ $day -gt $last_day ]; then
          last_day=$day
        fi
      fi
    fi
  done

  echo "$1-$last_day-$last_month-$last_year"
}

function size_in_octet() {
  # echo "$1"
  value=$(echo $1 | cut -d' ' -f1) #| tr '.' ',')
  unit=$(echo $1 | cut -d' ' -f2)
  # echo "$value"
  # echo "$unit"
  if [ $unit = "KiB" ]; then
    size=$(echo "$value*1024" | bc)
  elif [ $unit = "MiB" ]; then
    size=$(echo "$value*1024*1024" | bc)
  elif [ $unit = "GiB" ]; then
    size=$(echo "$value*1024*1024*1024" | bc)
  else
    echo "Can't parse unit: $unit"
    exit 1
  fi

  echo $size
}

function compare_dump_size() {
  set -e
  # echo "size1: $1 unit1: $2"
  # echo "size2: $3 unit2: $4"
  size1=$(size_in_octet "$1 $2")
  size2=$(size_in_octet "$3 $4")
  # echo "size1: $size1"
  # echo "size2: $size2"
  diff=$(echo "($size2-$size1)*100/$size1" | bc)
  echo "$diff"
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
  set -e

  echo "Starting Backup Postgres"

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$POSTGRES_DATABASE-$DATEHOUR

  # DAY_BACKUP=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done)
  # # echo $DAY_BACKUP
  # if [ -n "$DAY_BACKUP" ]; then
  #   echo "Backup already exist. Exit..."
  #   exit 0
  # fi

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
    echo "Enabling compression"
    COMPRESSION="-Fc"
  else
    echo "Disabling compression"
    COMPRESSION=""
  fi

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    echo "Enabling encryption"

    ENCRYPTION="openssl aes-256-cbc -pbkdf2 -iter 100000 -kfile $ENCRYPTION_PASSWORD"
  else
    echo "Disabling encryption"
    ENCRYPTION=""
  fi

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER \
      -d $POSTGRES_DATABASE $FILTER_TABLE $EXCLUDE_TABLE $COMPRESSION 2> dump_error.log | $ENCRYPTION | \
      aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql
  else
    PGPASSWORD=$POSTGRES_PASSWD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER \
      -d $POSTGRES_DATABASE $FILTER_TABLE $EXCLUDE_TABLE $COMPRESSION 2> dump_error.log | \
      aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql
  fi

  if [[ -s "dump_error.log" ]]; then
    cat dump_error.log
    exit 6
  fi

  DATE_ENDING=`date +%s`
  echo "Backup Done"

  SIZE=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls --summarize --human-readable s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql | grep "Total Size" | awk -F': ' '{print $2}')
  if [[ ! $SIZE =~ ^[0-9]+(\.[0-9]+)?[[:space:]][K|M|G]iB$ ]]; then
    echo "Can't get backup Size from S3 ($SIZE)"
    exit 2
  fi
  TIME=$(secs_to_human $DATE_ENDING $DATE_BEGIN)
  if [[ ! $TIME =~ ^[0-9]+h[[:space:]][0-9]{1,2}m[[:space:]][0-9]{1,2}s$ ]]; then
    echo "Error with Time Calcul ($TIME)"
    exit 3
  fi

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

  # LAST_BACKUP=$(check_last_backup "postgres" "postgres-$DATE.done")
  # if [[ ! $LAST_BACKUP =~ ^postgres-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
  #   echo "Can't get last backup name from S3 ($LAST_BACKUP)"
  #   exit 4
  # fi
  # echo "Last Backup: $LAST_BACKUP.done"
  # LAST_SIZE_BACKUP=$(aws --endpoint-url $S3_DESTINATION_HOST s3 cp s3://$S3_DESTINATION_BUCKET/$LAST_BACKUP.done - | grep "Dump size:" | cut -d':' -f2)
  # if [[ ! $LAST_SIZE_BACKUP =~ ^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]][K|M|G]iB$ ]]; then
  #   echo "Can't get last backup Size from S3 ($LAST_SIZE_BACKUP)"
  #   exit 5
  # fi
  # echo "Last Backup Size: $LAST_SIZE_BACKUP"

  # DIFF=$(compare_dump_size $SIZE $LAST_SIZE_BACKUP)
  # # [[ ! $DIFF =~ ^$ ]] && echo "Something wrong with diff calcul"; exit 6
  # echo "Difference since last backup: $DIFF%"

  # if [ $DIFF -lt -5 ] || [ $DIFF -gt 5 ]; then
  #   echo "Difference too big: $DIFF%"
  #   exit 1
  # fi

  # echo "Backup checked"

  set +e
  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/postgres-$DATE
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done

  exit 0
}

function backupAllPostgresToBucket() {
  set -e

  echo "Starting Backup All Postgres"

  DATE=$(date +"%d-%m-%Y")
  DATEHOUR=$(date +"%d-%m-%Y_%H-%M-%S")
  FILE=backup-$POSTGRES_DATABASE-$DATEHOUR

  # DAY_BACKUP=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done)
  # # echo $DAY_BACKUP
  # if [ -n "$DAY_BACKUP" ]; then
  #   echo "Backup already exist. Exit..."
  #   exit 0
  # fi

  # if [ "$COMPRESSION_ENABLE" = "true" ]; then
  #   echo "Enable compression"
  #   COMPRESSION="-Fc"
  # else
  #   echo "Disable compression"
  #   COMPRESSION=""
  # fi

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    echo "Enabling encryption"

    ENCRYPTION="openssl aes-256-cbc -pbkdf2 -iter 100000 -kfile $ENCRYPTION_PASSWORD"
  else
    echo "Disabling encryption"
    ENCRYPTION=""
  fi

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    PGPASSWORD=$POSTGRES_PASSWD pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER --database=$POSTGRES_DATABASE 2> dump_error.log \
      | $ENCRYPTION | aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql
  else
    PGPASSWORD=$POSTGRES_PASSWD pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER --database=$POSTGRES_DATABASE 2> dump_error.log \
      | aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql
  fi

  if [[ -s "dump_error.log" ]]; then
    cat dump_error.log
    exit 6
  fi

  DATE_ENDING=`date +%s`
  echo "Backup Done"

  SIZE=$(aws --endpoint-url $S3_DESTINATION_HOST s3 ls --summarize --human-readable s3://$S3_DESTINATION_BUCKET/postgres-$DATE/$FILE.sql | grep "Total Size" | awk -F': ' '{print $2}')
  if [[ ! $SIZE =~ ^[0-9]+(\.[0-9]+)?[[:space:]][K|M|G]iB$ ]]; then
    echo "Can't get backup Size from S3 ($SIZE)"
    exit 2
  fi
  TIME=$(secs_to_human $DATE_ENDING $DATE_BEGIN)
  if [[ ! $TIME =~ ^[0-9]+h[[:space:]][0-9]{1,2}m[[:space:]][0-9]{1,2}s$ ]]; then
    echo "Error with Time computation ($TIME)"
    exit 3
  fi

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

  # LAST_BACKUP=$(check_last_backup "postgres" "postgres-$DATE.done")
  # if [[ ! $LAST_BACKUP =~ ^postgres-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
  #   echo "Can't get last backup name from S3 ($LAST_BACKUP)"
  #   exit 4
  # fi
  # echo "Last Backup: $LAST_BACKUP.done"
  # LAST_SIZE_BACKUP=$(aws --endpoint-url $S3_DESTINATION_HOST s3 cp s3://$S3_DESTINATION_BUCKET/$LAST_BACKUP.done - | grep "Dump size:" | cut -d':' -f2)
  # if [[ ! $LAST_SIZE_BACKUP =~ ^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]][K|M|G]iB$ ]]; then
  #   echo "Can't get last backup Size from S3 ($LAST_SIZE_BACKUP)"
  #   exit 5
  # fi
  # echo "Last Backup Size: $LAST_SIZE_BACKUP"

  # DIFF=$(compare_dump_size $SIZE $LAST_SIZE_BACKUP)
  # # [[ ! $DIFF =~ ^$ ]] && echo "Something wrong with diff calcul"; exit 6
  # echo "Difference since last backup: $DIFF%"

  # if [ $DIFF -lt -5 ] || [ $DIFF -gt 5 ]; then
  #   echo "Difference too big: $DIFF%"
  #   exit 1
  # fi

  # echo "Backup checked"

  set +e
  echo "Remove old folder"
  DATE=$(date -d "$RETENTION days ago" +"%d-%m-%Y")
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm --recursive s3://$S3_DESTINATION_BUCKET/postgres-$DATE
  aws --endpoint-url $S3_DESTINATION_HOST s3 rm s3://$S3_DESTINATION_BUCKET/postgres-$DATE.done

  exit 0
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

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    echo "Enabling encryption"

    ENCRYPTION="openssl aes-256-cbc -pbkdf2 -iter 100000 -kfile $ENCRYPTION_PASSWORD"
  else
    echo "Disabling encryption"
    ENCRYPTION=""
  fi

  echo "Begin Backup..."
  DATE_BEGIN=`date +%s`

  BACKUP_COMMAND="mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD \
    --databases $MYSQL_DATABASE"
  AWS_COMMAND="aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/mysql-$DATE/$FILE"

  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD --databases $MYSQL_DATABASE \
      | $ENCRYPTION | aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/mysql-$DATE/$FILE
  else
    mysqldump --host $MYSQL_HOST --port $MYSQL_PORT --user $MYSQL_USER -p$MYSQL_PASSWD --databases $MYSQL_DATABASE \
      | aws --endpoint-url $S3_DESTINATION_HOST s3 cp - s3://$S3_DESTINATION_BUCKET/mysql-$DATE/$FILE
  fi

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
  if [ "$ENCRYPTION_ENABLE" = "true" ]; then
    cat $FILE | openssl aes-256-cbc -pbkdf2 -iter 100000 -kfile $ENCRYPTION_PASSWORD -out $FILE.tmp
    rm $FILE
    mv $FILE.tmp $FILE
  fi

  aws --endpoint-url $S3_DESTINATION_HOST s3 cp $FILE s3://$S3_DESTINATION_BUCKET/redis-$DATE/$FILE

  rm $FILE

  echo "Backup Done"
}

function backupFileSystemToBucket() {

  set -e
  /go/backup-tool --mode-debug --backup-role $FILESYSTEM_BACKUP_ROLE

}
