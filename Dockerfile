#FROM redis:5.0-alpine AS Redis

FROM alpine:3.7

# S3 Environments Variables
ENV SRC=bucket
ENV DST=bucket

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
                       python3 \
                       py-pip

RUN apk add --update --no-cache coreutils

RUN curl  https://dl.minio.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc && \
    chmod +x /usr/bin/mc

COPY *.sh /
COPY PythonScripts /PythonScripts
RUN pip install --upgrade pip && \
    pip install -r /PythonScripts/requirements.txt
#COPY --from=Redis /usr/local/bin/redis-cli /usr/local/bin/redis-cli
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]