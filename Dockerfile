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

RUN apk --no-cache add bash \
                       curl

RUN apk add --update --no-cache coreutils

RUN curl  https://dl.minio.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc && \
    chmod +x /usr/bin/mc

ADD *.sh /
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]