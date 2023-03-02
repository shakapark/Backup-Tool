# Backup-Tool

Battery of Bash & Python scripts to backup multi source to multi destination.

## TODO List

- [x] Backup Postgres Database to Bucket S3
- [x] Backup Postgres server to Bucket S3
- [x] Backup MySQL to Bucket S3
- [x] Backup Bucket S3 to Bucket S3
- [ ] Backup Blob Container to Bucket S3
- [ ] Backup Postgres Database to Blob Container
- [ ] Backup Postgres server to Blob Container
- [ ] Backup MySQL to Blob Container
- [ ] Backup Bucket S3 to Blob Container
- [x] Restore Postgres Database from Bucket S3
- [ ] Restore Postgres server from Bucket S3
- [ ] Restore MySQL from Bucket S3
- [x] Restore Bucket S3 from Bucket S3
- [ ] Restore Blob Container from Bucket S3
- [ ] Restore Postgres Database from Blob Container
- [ ] Restore Postgres server from Blob Container
- [ ] Restore MySQL from Blob Container
- [ ] Restore Bucket S3 from Blob Container
- [ ] Restore Blob Container from Blob Container

## Configuration

### Backup to Bucket S3

|             ENV             |  Default Value  |                                  Description                                   |
|:---------------------------:|:---------------:|:------------------------------------------------------------------------------:|
|           ACTION            |      NONE       | Set ACTION to BACKUP if you want to make a backup                              |
|          SRC_TYPE           |      NONE       | Choose between BucketAWS, Postgres, AllPostgres, Mysql, Redis                  |
|   AWS_MULTIPART_THRESHOLD   |       1GB       | AWS binary option (not available for bucket backup)                            |
|   AWS_MULTIPART_CHUNKSIZE   |      512MB      | AWS binary option (not available for bucket backup)                            |
|      AWS_MAX_BANDWIDTH      |      5MB/s      | AWS binary option (not available for bucket backup)                            |
| AWS_MAX_CONCURRENT_REQUESTS |        1        | AWS binary option (not available for bucket backup)                            |
|    S3_DESTINATION_BUCKET    |      NONE       | Define the bucket name for S3 where backup will be upload                      |
|     S3_DESTINATION_HOST     | https://s3.amazonaws.com | Define the url for S3 where backup will be upload                     |
|    S3_DESTINATION_REGION    |    eu-west-1    | Define the region name for S3 where backup will be upload                      |
|  S3_DESTINATION_ACCESS_KEY  |      NONE       | Define the access key credential for S3 where backup will be upload            |
|  S3_DESTINATION_SECRET_KEY  |      NONE       | Define the secret key credential for S3 where backup will be upload            |
|      S3_SOURCE_BUCKET       |      NONE       | If SRC_TYPE=BucketAWS, define the bucket name for S3 that will be backup       |
|       S3_SOURCE_HOST        | https://s3.amazonaws.com | If SRC_TYPE=BucketAWS, define the url for S3 that will be backup      |
|      S3_SOURCE_REGION       |    eu-west-1    | If SRC_TYPE=BucketAWS, define the region name for S3 that will be backup       |
|    S3_SOURCE_ACCESS_KEY     |      NONE       | If SRC_TYPE=BucketAWS, define the access key credential for S3 that will be backup |
|    S3_SOURCE_SECRET_KEY     |      NONE       | If SRC_TYPE=BucketAWS, define the secret key credential for S3 that will be backup |
|        POSTGRES_HOST        |    127.0.0.1    | If SRC_TYPE=Postgres|AllPostgres, define the postgres host that will be backup |
|        POSTGRES_PORT        |      5432       | If SRC_TYPE=Postgres|AllPostgres, define the postgres port that will be backup |
|        POSTGRES_USER        |    postgres     | If SRC_TYPE=Postgres|AllPostgres, define the postgres user that will be backup |
|       POSTGRES_PASSWD       |    postgres     | If SRC_TYPE=Postgres|AllPostgres, define the postgres password that will be backup |
|      POSTGRES_DATABASE      |    postgres     | If SRC_TYPE=Postgres, define the postgres database that will be backup         |
|      COMPRESSION_ENABLE     |     false       | If SRC_TYPE=Postgres|AllPostgres, enable or disable backup compression         |
|       POSTGRES_TABLE        |      NONE       | If SRC_TYPE=Postgres, enable or disable tables filter (comma separated list)   |
|   POSTGRES_EXCLUDE_TABLE    |      NONE       | If SRC_TYPE=Postgres, enable or disable tables filter (comma separated list)   |
|         MYSQL_HOST          |    127.0.0.1    | If SRC_TYPE=Mysql, define the mysql host that will be backup                   |
|         MYSQL_PORT          |      3306       | If SRC_TYPE=Mysql, define the mysql port that will be backup                   |
|         MYSQL_USER          |      mysql      | If SRC_TYPE=Mysql, define the mysql user that will be backup                   |
|        MYSQL_PASSWD         |      mysql      | If SRC_TYPE=Mysql, define the mysql password that will be backup               |
|       MYSQL_DATABASE        |      mysql      | If SRC_TYPE=Mysql, define the mysql database that will be backup               |
|         REDIS_HOST          |    127.0.0.1    | If SRC_TYPE=Redis, define the redis host that will be backup                   |
|         REDIS_PORT          |      6379       | If SRC_TYPE=Redis, define the port for redis that will be backup               |
|       REDIS_PASSWORD        |      NONE       | If SRC_TYPE=Redis, define the password for redis that will be backup           |

### Restore from Bucket S3

|             ENV             |  Default Value  |                                  Description                                  |
|:---------------------------:|:---------------:|:-----------------------------------------------------------------------------:|
|           ACTION            |      NONE       | Set ACTION to RESTORE if you want restore a backup                            |
|         BACKUP_NAME         |      NONE       | Backup name in bucket S3                                                      |
|          DST_TYPE           |      NONE       | Choose between BucketAWS, Postgres                                            |
|   AWS_MULTIPART_THRESHOLD   |       1GB       | AWS binary option (not available for bucket restore)                          |
|   AWS_MULTIPART_CHUNKSIZE   |      512MB      | AWS binary option (not available for bucket restore)                          |
|      AWS_MAX_BANDWIDTH      |      5MB/s      | AWS binary option (not available for bucket restore)                          |
| AWS_MAX_CONCURRENT_REQUESTS |        1        | AWS binary option (not available for bucket restore)                          |
|    S3_DESTINATION_BUCKET    |      NONE       | Define the bucket name for S3 where backup will be download                   |
|     S3_DESTINATION_HOST     | https://s3.amazonaws.com | Define the url for S3 where backup will be download                  |
|    S3_DESTINATION_REGION    |    eu-west-1    | Define the region name for S3 where backup will be download                   |
|  S3_DESTINATION_ACCESS_KE   |      NONE       | Define the access key credential for S3 where backup will be download         |
|  S3_DESTINATION_SECRET_KEY  |      NONE       | Define the secret key credential for S3 where backup will be download         |
|      S3_SOURCE_BUCKET       |      NONE       | If DST_TYPE=BucketAWS, define the bucket name that will be restored           |
|       S3_SOURCE_HOST        | https://s3.amazonaws.com | If DST_TYPE=BucketAWS, define the s3 url that will be restored       |
|      S3_SOURCE_REGION       |    eu-west-1    | If DST_TYPE=BucketAWS, define the s3 region name that will be restored        |
|    S3_SOURCE_ACCESS_KEY     |      NONE       | If DST_TYPE=BucketAWS, define the access key credential that will be restored |
|    S3_SOURCE_SECRET_KEY     |      NONE       | If DST_TYPE=BucketAWS, define the secret key credential that will be restored |
|        POSTGRES_HOST        |    127.0.0.1    | If DST_TYPE=Postgres, define the postgres host that will be restored          |
|        POSTGRES_PORT        |      5432       | If DST_TYPE=Postgres, define the postgres port that will be restored          |
|        POSTGRES_USER        |    postgres     | If DST_TYPE=Postgres, define the postgres user that will be restored          |
|       POSTGRES_PASSWD       |    postgres     | If DST_TYPE=Postgres, define the postgres password that will be restored      |
|      POSTGRES_DATABASE      |    postgres     | If DST_TYPE=Postgres, define the postgres database that will be restored      |
|      COMPRESSION_ENABLE     |     false       | If DST_TYPE=Postgres, enable or disable backup compression                    |
|                             |                 |                                                                               |
