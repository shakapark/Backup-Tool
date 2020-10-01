FROM alpine:3.10

# S3 Environments Variables
ENV SRC="bucket-src"
ENV S3_SOURCE_HOST="https://s3.amazonaws.com"
ENV S3_SOURCE_ACCESS_KEY=""
ENV S3_SOURCE_SECRET_KEY=""
ENV DST="bucket-dst"
ENV S3_DESTINATION_HOST="https://s3.amazonaws.com"
ENV S3_DESTINATION_ACCESS_KEY=""
ENV S3_DESTINATION_SECRET_KEY=""

# Postgres Environments Variables
ENV POSTGRES_HOST=127.0.0.1
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWD=postgres
ENV POSTGRES_DATABASE=postgres

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

RUN apk --no-cache add bash \
                       curl \
                       postgresql-client \
                       mariadb-client \
                       python3

RUN apk add --update --no-cache coreutils

RUN curl  https://dl.minio.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc && \
    chmod +x /usr/bin/mc

COPY config/ /config
COPY *.sh /
COPY PythonScripts /PythonScripts
RUN pip3 install --upgrade pip && \
    pip3 install -r /PythonScripts/requirements.txt
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
