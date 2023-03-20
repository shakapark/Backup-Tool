package backuptool

import (
	"bytes"
	"context"
	"errors"
	"os"
	"strings"
	"sync"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type backupResult struct {
	debug  error
	errors error
}

func newBackupResult(d, e error) backupResult {
	return backupResult{
		debug:  d,
		errors: e,
	}
}
func (br backupResult) getError() error {
	return br.errors
}
func (br backupResult) getDebug() error {
	return br.debug
}
func (br1 backupResult) joinResult(br2 backupResult) backupResult {
	return backupResult{
		debug:  errors.Join(br1.debug, br2.debug),
		errors: errors.Join(br1.errors, br2.errors),
	}
}

func uploadFile(client *s3.Client, bucket, path, prefix string, wg *sync.WaitGroup, ch chan backupResult) {

	defer wg.Done()
	debug := errors.New("upload file: " + path)

	file, err := os.Open(path)
	if err != nil {
		ch <- newBackupResult(debug, errors.Join(errors.New("error opening file path: "+path), err))
		return
	}
	defer file.Close()

	fileInfo, _ := file.Stat()
	var fileSize int64 = fileInfo.Size()
	fileBuffer := make([]byte, fileSize)

	key := prefix + fileInfo.Name()

	putObjectParams := &s3.PutObjectInput{
		Bucket: &bucket,
		Key:    &key,
		Body:   bytes.NewReader(fileBuffer),
	}

	_, err2 := client.PutObject(context.TODO(), putObjectParams)
	if err2 != nil {
		ch <- newBackupResult(debug, errors.Join(errors.New("error upload file path: "+path), err2))
		return
	}

	ch <- newBackupResult(debug, nil)
}

func uploadFolder(client *s3.Client, bucket, path, prefix string, wg *sync.WaitGroup, ch chan backupResult) {

	defer wg.Done()

	debug := errors.New("Boucle for path: " + path)

	files, err := os.ReadDir(path)
	if err != nil {
		ch <- newBackupResult(debug, errors.Join(errors.New("error during listing path: "+path), err))
		return
	}

	for _, file := range files {
		debug = errors.Join(debug, errors.New("File: "+file.Name()))
		wg.Add(1)
		if file.IsDir() {
			go uploadFolder(client, bucket, path+"/"+file.Name(), prefix+"/"+file.Name(), wg, ch)
		} else {
			uploadFile(client, bucket, path+"/"+file.Name(), prefix+"/", wg, ch)
		}
	}
	ch <- newBackupResult(debug, nil)
}

func backupFileSystem(client *s3.Client, s3c *S3Config, path string, js *JobStatus) (error, error) {

	fpath, fileErr := os.Stat(path)
	if fileErr != nil {
		return nil, errors.Join(errors.New("error opening path: "+path), fileErr)
	}

	path = strings.TrimSuffix(path, "/")
	prefix := "filesystem-" + js.JobBeginDate.Format("02-01-2006") + "/"
	prefixPath := strings.ReplaceAll(strings.TrimPrefix(path, "/"), "/", "-")
	prefix = prefix + "backup-" + prefixPath + "-" + js.JobBeginDate.Format("02-01-2006_15-04-05")

	ch := make(chan backupResult, 99999)
	wg := new(sync.WaitGroup)

	wg.Add(1)
	if fpath.IsDir() {
		go uploadFolder(client, s3c.s3DestinationBucket, path, prefix, wg, ch)
	} else {
		uploadFile(client, s3c.s3DestinationBucket, path, prefix+"/", wg, ch)
	}

	wg.Wait()
	close(ch)

	// for ch := range chErr {
	// 	errJob = errors.Join(errJob, ch)
	// }

	var results backupResult
	// for result := range ch {
	// 	results = results.joinResult(result)
	// }
	for {
		result, ok := <-ch
		if ok {
			results = results.joinResult(result)
		} else {
			break
		}
	}

	js.updateDuration()

	return results.getDebug(), results.getError()
}
