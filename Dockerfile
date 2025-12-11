FROM golang:1.25 AS gobuild
ADD Go/ /go/src/Backup-Tool/
WORKDIR /go/src/Backup-Tool/
RUN go mod tidy && go mod vendor
RUN CGO_ENABLED=0 go build -o backup-tool cmd/FileSystemBackup/main.go
RUN ls -al

FROM alpine:3.22

# ENV ACTION="BACKUP|RESTORE"

# Backup Environments Variables
# ENV RETENTION=""

# Restore Environments Variables
ENV BACKUP_NAME=""

# AWS Environments Variables
ENV AWS_MULTIPART_THRESHOLD="1GB"
ENV AWS_MULTIPART_CHUNKSIZE="512MB"
ENV AWS_MAX_BANDWIDTH="5MB/s"
ENV AWS_MAX_CONCURRENT_REQUESTS="1"

# S3 Environments Variables
ENV S3_SOURCE_BUCKET="bucket-src"
ENV S3_SOURCE_HOST="https://s3.amazonaws.com"
ENV S3_SOURCE_REGION="eu-west-1"
# ENV S3_SOURCE_ACCESS_KEY=""
# ENV S3_SOURCE_SECRET_KEY=""
ENV S3_SOURCE_PATH_STYLE=false

ENV S3_DESTINATION_BUCKET="bucket-dst"
ENV S3_DESTINATION_HOST="https://s3.amazonaws.com"
ENV S3_DESTINATION_REGION="eu-west-1"
# ENV S3_DESTINATION_ACCESS_KEY=""
# ENV S3_DESTINATION_SECRET_KEY=""
ENV S3_DESTINATION_PATH_STYLE=false

# Postgres Environments Variables
ENV POSTGRES_HOST=127.0.0.1
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=postgres
# ENV POSTGRES_PASSWD=postgres
ENV POSTGRES_DATABASE=postgres
ENV COMPRESSION_ENABLE=false

# ENV POSTGRES_TABLE=""
# ENV POSTGRES_EXCLUDE_TABLE=""
# ENV PG_RESTORE_EXTRA_OPTS=""

# MySql Environments Variables
ENV MYSQL_HOST=127.0.0.1
ENV MYSQL_PORT=3306
ENV MYSQL_USER=mysql
# ENV MYSQL_PASSWD=mysql
ENV MYSQL_DATABASE=mysql

# Redis Environments Variables
ENV REDIS_HOST=127.0.0.1
ENV REDIS_PORT=6379
# ENV REDIS_PASSWORD

# Filesystem Environments Variables
ENV FILESYSTEM_BACKUP_ROLE="job"
ENV FILESYSTEM_PATH=""
ENV SERVER_LISTEN_ADDRESS=":12000"
ENV SERVER_ADDRESS="http://127.0.0.1:12000"

# generate couple of key with:
#  openssl rand -base64 256 | tr -d '\n'
ENV ENCRYPTION_FILE="/var/backup/password"
ENV ENCRYPTION_ENABLE=false

RUN apk --update --no-cache add aws-cli \
                        bash \
                        coreutils \
                        curl \
                        gettext \
                        gzip \
                        mariadb-client \
                        postgresql-client \
                        python3 \
                        py3-pip \
                        openssl

#COPY PythonScripts /PythonScripts
#RUN pip3 install -r /PythonScripts/requirements.txt

COPY config/ /config
COPY *.sh /

RUN chmod +x /entrypoint.sh

COPY --from=gobuild /go/src/Backup-Tool/backup-tool /go/backup-tool

ENTRYPOINT ["/entrypoint.sh"]
