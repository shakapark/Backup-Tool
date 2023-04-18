package backuptool

import (
	"errors"
	"os"
	"strconv"
	"time"
)

type RequestConfig struct {
	serverAddress string
}

func (rc *RequestConfig) GetServerAddress() string {
	return rc.serverAddress
}

type ServerConfig struct {
	listenAddress string
}

func (sc *ServerConfig) GetListensAddress() string {
	return sc.listenAddress
}

type S3Config struct {
	s3DestinationBucket    string
	s3DestinationHost      string
	s3DestinationRegion    string
	s3DestinationAccessKey string
	s3DestinationSecretKey string
	s3DestinationPathStyle bool
}

type JobConfig struct {
	fileSystemPath string
	retention      time.Duration
	s3Config       *S3Config
	debug          bool
}

func (jc *JobConfig) getS3Config() *S3Config {
	return jc.s3Config
}
func (jc *JobConfig) getPath() string {
	return jc.fileSystemPath
}
func (jc *JobConfig) getRetention() time.Duration {
	return jc.retention
}

func getS3Config() (*S3Config, error) {

	var err error
	s3DestinationBucket := os.Getenv("S3_DESTINATION_BUCKET")
	if s3DestinationBucket == "" {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_BUCKET is undefined"), err)
	}

	s3DestinationHost := os.Getenv("S3_DESTINATION_HOST")
	if s3DestinationHost == "" {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_HOST is undefined"), err)
	}

	s3DestinationRegion := os.Getenv("S3_DESTINATION_REGION")
	if s3DestinationRegion == "" {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_REGION is undefined"), err)
	}

	s3DestinationAccessKey := os.Getenv("S3_DESTINATION_ACCESS_KEY")
	if s3DestinationAccessKey == "" {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_ACCESS_KEY is undefined"), err)
	}

	s3DestinationSecretKey := os.Getenv("S3_DESTINATION_SECRET_KEY")
	if s3DestinationSecretKey == "" {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_SECRET_KEY is undefined"), err)
	}

	s3DestinationPathStyle, errBool := strconv.ParseBool(os.Getenv("S3_DESTINATION_PATH_STYLE"))
	if errBool != nil {
		err = errors.Join(errors.New("environment variable S3_DESTINATION_PATH_STYLE must be false or true"), err)
	}

	return &S3Config{
		s3DestinationBucket:    s3DestinationBucket,
		s3DestinationHost:      s3DestinationHost,
		s3DestinationRegion:    s3DestinationRegion,
		s3DestinationAccessKey: s3DestinationAccessKey,
		s3DestinationSecretKey: s3DestinationSecretKey,
		s3DestinationPathStyle: s3DestinationPathStyle,
	}, err
}

func getJobConfig(debug bool) (*JobConfig, error) {

	s3Config, err := getS3Config()

	fileSystemPath := os.Getenv("FILESYSTEM_PATH")
	if fileSystemPath == "" {
		err = errors.Join(errors.New("environment variable FILESYSTEM_PATH is undefined"), err)
	}

	var retentionDuration time.Duration
	ret := os.Getenv("RETENTION")
	if ret != "" {
		retentionInt, err2 := strconv.Atoi(os.Getenv("RETENTION"))
		if err2 != nil {
			err = errors.Join(errors.Join(errors.New("error parsing RETENTION env"), err2), err)
		} else {
			var err4 error
			retentionDuration, err4 = time.ParseDuration("-" + strconv.Itoa(retentionInt*24) + "h")
			if err4 != nil {
				err = errors.Join(errors.Join(errors.New("error parsing RETENTION env"), err4), err)
			}
		}
	}

	return &JobConfig{
		fileSystemPath: fileSystemPath,
		retention:      retentionDuration,
		s3Config:       s3Config,
		debug:          debug,
	}, err
}

func GetServerConfig() *ServerConfig {
	listenAddress := os.Getenv("SERVER_LISTEN_ADDRESS")
	return &ServerConfig{
		listenAddress: listenAddress,
	}
}

func GetRequestConfig() (*RequestConfig, error) {
	var err error
	serverAddress := os.Getenv("SERVER_ADDRESS")
	if serverAddress == "" {
		err = errors.New("environment variable SERVER_ADDRESS is undefined")
	}
	return &RequestConfig{
		serverAddress: serverAddress,
	}, err
}
