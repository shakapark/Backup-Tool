[default]
region = $S3_DESTINATION_REGION
s3 =
  max_concurrent_requests = $AWS_MAX_CONCURRENT_REQUESTS
  max_bandwidth = $AWS_MAX_BANDWIDTH
  addressing_style = path
  multipart_threshold = $AWS_MULTIPART_THRESHOLD
  multipart_chunksize = $AWS_MULTIPART_CHUNKSIZE