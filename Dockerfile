FROM alpine:3.10

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
                       mariadb-client \
                       postgresql-client \
                       python3 \
                       tar

RUN apk add --update --no-cache coreutils

RUN curl  https://dl.minio.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc && \
    chmod +x /usr/bin/mc

RUN curl https://azcopyvnext.azureedge.net/release20191113/azcopy_linux_amd64_10.3.2.tar.gz -o azcopy_v10.3.2.tar.gz && \
    tar -xf azcopy_v10.3.2.tar.gz --exclude=ThirdPartyNotice.txt --strip-components=1 --directory /usr/bin/ && \
    rm azcopy_v10.3.2.tar.gz

COPY *.sh /
COPY PythonScripts /PythonScripts
RUN pip3 install --upgrade pip && \
    pip3 install -r /PythonScripts/requirements.txt
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
