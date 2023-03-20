package backuptool

import (
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func newS3Client(s3c *S3Config) *s3.Client {

	var hostnameImmutable bool
	if s3c.s3DestinationHost == "https://s3.amazonaws.com" {
		hostnameImmutable = false
	} else {
		hostnameImmutable = true
	}

	resolver := aws.EndpointResolverWithOptionsFunc(
		func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{
				PartitionID:       "aws",
				URL:               s3c.s3DestinationHost,
				SigningRegion:     s3c.s3DestinationRegion,
				HostnameImmutable: hostnameImmutable,
			}, nil
		})

	return s3.NewFromConfig(aws.Config{
		Region:                      s3c.s3DestinationRegion,
		Credentials:                 credentials.NewStaticCredentialsProvider(s3c.s3DestinationAccessKey, s3c.s3DestinationSecretKey, ""),
		EndpointResolverWithOptions: resolver,
	}, func(o *s3.Options) {
		o.UsePathStyle = s3c.s3DestinationPathStyle
	})
}
