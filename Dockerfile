FROM alpine:3.10

# S3 Environments Variables
ENV S3_SOURCE_BUCKET="bucket-src"
ENV S3_SOURCE_HOST="https://s3.amazonaws.com"
ENV S3_SOURCE_REGION="eu-west-1"
ENV S3_SOURCE_ACCESS_KEY=""
ENV S3_SOURCE_SECRET_KEY=""

ENV S3_DESTINATION_BUCKET="bucket-dst"
ENV S3_DESTINATION_HOST="https://s3.amazonaws.com"
ENV S3_DESTINATION_REGION="eu-west-1"
ENV S3_DESTINATION_ACCESS_KEY=""
ENV S3_DESTINATION_SECRET_KEY=""

# Postgres Environments Variables
ENV POSTGRES_HOST=127.0.0.1
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWD=postgres
ENV POSTGRES_DATABASE=postgres
ENV COMPRESSION_ENABLE=false

# ENV POSTGRES_TABLE=""
# ENV POSTGRES_EXCLUDE_TABLE=""

# MySql Environments Variables
ENV MYSQL_HOST=127.0.0.1
ENV MYSQL_PORT=3306
ENV MYSQL_USER=mysql
ENV MYSQL_PASSWD=mysql
ENV MYSQL_DATABASE=mysql

# Redis Environments Variables
ENV REDIS_HOST=127.0.0.1
ENV REDIS_PORT=6379
# ENV REDIS_PASSWORD

RUN apk --update --no-cache add bash \
                        coreutils \
                        curl \
                        gettext \
                        gzip \
                        mariadb-client \
                        postgresql-client \
                        python3 \
                        py3-pip

COPY config/ /config
COPY *.sh /
COPY PythonScripts /PythonScripts

RUN pip3 install --upgrade pip && \
    pip3 install awscli && \
    pip3 install -r /PythonScripts/requirements.txt

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
