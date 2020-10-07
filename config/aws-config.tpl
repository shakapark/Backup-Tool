[default]
region = $S3_DESTINATION_REGION
s3 =
  addressing_style = path
  multipart_threshold = $AWS_MULTIPART_THRESHOLD
  multipart_chunksize = $AWS_MULTIPART_CHUNKSIZE