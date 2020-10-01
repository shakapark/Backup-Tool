{
    "version": "9",
    "hosts": {
        "source": {
            "url": "$S3_SOURCE_HOST",
            "accessKey": "$S3_SOURCE_ACCESS_KEY",
            "secretKey": "$S3_SOURCE_SECRET_KEY",
            "api": "S3v4",
            "lookup": "auto"
        },
        "destination": {
            "url": "$S3_DESTINATION_HOST",
            "accessKey": "$S3_DESTINATION_ACCESS_KEY",
            "secretKey": "$S3_DESTINATION_SECRET_KEY",
            "api": "S3v4",
            "lookup": "auto"
        }
    }
}
