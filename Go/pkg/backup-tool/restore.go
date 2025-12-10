package backuptool

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type restoreResult struct {
	debug  error
	errors error
}

func newRestoreResult(d, e error) restoreResult {
	return restoreResult{
		debug:  d,
		errors: e,
	}
}
func (rr restoreResult) getError() error {
	return rr.errors
}
func (rr restoreResult) getDebug() error {
	return rr.debug
}
func (rr1 restoreResult) joinResult(rr2 restoreResult) restoreResult {
	return restoreResult{
		debug:  errors.Join(rr1.debug, rr2.debug),
		errors: errors.Join(rr1.errors, rr2.errors),
	}
}

func isS3File(client *s3.Client, bucket string, path string) bool {
	headObjectParams := &s3.HeadObjectInput{
		Bucket: &bucket,
		Key:    &path,
	}
	_, err := client.HeadObject(context.TODO(), headObjectParams)
	return err == nil
}
func isS3Folder(client *s3.Client, bucket string, path string) bool {
	listObjectParams := &s3.ListObjectsV2Input{
		Bucket: &bucket,
		Prefix: &path,
	}
	listObjectOutput, err := client.ListObjectsV2(context.TODO(), listObjectParams)
	if err != nil {
		return false
	}
	if len(listObjectOutput.Contents) == 0 {
		return false
	}
	if len(listObjectOutput.Contents) == 1 {
		isFile := isS3File(client, bucket, path)
		if isFile {
			return false
		}

	}

	return true
}

func getLasts3Path(s3Path string) string {
	folders := strings.Split(s3Path, "/")
	if folders[len(folders)-1] == "" {
		return folders[len(folders)-2]
	} else {
		return folders[len(folders)-1]
	}
}

func decryptFile(fileName string, passwordFile string) (string, error) {
	password, err := GetPasswordFromFile(passwordFile)
	if err != nil {
		return "", err
	}

	var encryptFileName string
	if strings.HasSuffix(fileName, ".enc") {
		encryptFileName = strings.Trim(fileName, ".enc")
	} else {
		encryptFileName = fileName + ".dec"
	}
	err = DecryptFile(fileName, encryptFileName, password)
	if err != nil {
		return "", err
	}

	return encryptFileName, nil
}

func restoreFile(client *s3.Client, bucket string, s3Path string, folder string, file string, encryption bool, keyPath string, wg *sync.WaitGroup, ch chan restoreResult) {

	defer wg.Done()
	debug := errors.New("restore file: " + s3Path)

	getObjectInput := &s3.GetObjectInput{
		Bucket: &bucket,
		Key:    &s3Path,
	}
	getObjectOutput, err := client.GetObject(context.TODO(), getObjectInput)
	if err != nil {
		ch <- newRestoreResult(debug, errors.Join(errors.New("error getting object path: "+s3Path), err))
		return
	}
	defer getObjectOutput.Body.Close()

	if file == "" {
		_, file = filepath.Split(s3Path)
	}

	body, err2 := io.ReadAll(getObjectOutput.Body)
	if err2 != nil {
		ch <- newRestoreResult(debug, errors.Join(errors.New("error reading body"), err2))
		return
	}

	targetFilePath := filepath.Join(folder, file)
	targetFile, err3 := os.Create(targetFilePath)
	if err3 != nil {
		ch <- newRestoreResult(debug, errors.Join(errors.New("error creating file path: "+filepath.Join(folder, file)), err3))
		return
	}
	defer targetFile.Close()
	_, err4 := targetFile.Write(body)
	if err4 != nil {
		ch <- newRestoreResult(debug, errors.Join(errors.New("error writting file"), err4))
		return
	}

	if encryption {
		// targetEncryptFile, err3 := os.Create(targetEncryptFilePath)
		// if err3 != nil {
		// 	ch <- newRestoreResult(debug, errors.Join(errors.New("error creating file path: "+filepath.Join(folder, file)), err3))
		// 	return
		// }
		// defer targetEncryptFile.Close()
		defer os.Remove(targetFilePath)

		_, err5 := decryptFile(targetFilePath, keyPath)
		if err5 != nil {
			ch <- newRestoreResult(debug, errors.Join(errors.New("error decrypt file"), err5))
			return
		}
	}
	ch <- newRestoreResult(debug, nil)
}

func restoreFolder(client *s3.Client, bucket string, s3Path string, folder string, encryption bool, keyPath string, wg *sync.WaitGroup, ch chan restoreResult) {

	defer wg.Done()
	debug := errors.New("restore folder: " + s3Path + " in " + folder)

	delimiter := "/"
	// List s3 folder
	listObjectsV2Input := &s3.ListObjectsV2Input{
		Bucket:    &bucket,
		Prefix:    &s3Path,
		Delimiter: &delimiter,
	}
	listObjectsV2Ouput, err := client.ListObjectsV2(context.TODO(), listObjectsV2Input)
	if err != nil {
		ch <- newRestoreResult(debug, errors.Join(errors.New("error listing bucket"), err))
		return
	}

	for _, cp := range listObjectsV2Ouput.CommonPrefixes {
		debug = errors.Join(debug, errors.New("Test s3 path: "+*cp.Prefix))
		if isS3Folder(client, bucket, *cp.Prefix) {
			pathFolder := folder + getLasts3Path(*cp.Prefix)
			err2 := os.Mkdir(pathFolder, 0755)
			if err2 != nil && !os.IsExist(err2) {
				// if !os.IsExist(err2) {
				ch <- newRestoreResult(debug, err2)
				// } else {
				// 	wg.Add(1)
				// 	go restoreFolder(client, bucket, *cp.Prefix, pathFolder, wg, ch)
				// }
			} else {
				wg.Add(1)
				go restoreFolder(client, bucket, *cp.Prefix, pathFolder, encryption, keyPath, wg, ch)
			}
		} else {
			ch <- newRestoreResult(debug, errors.New(*cp.Prefix+" is not s3 folder"))
		}
	}

	for _, c := range listObjectsV2Ouput.Contents {
		debug = errors.Join(debug, errors.New("Test s3 path: "+*c.Key))
		if isS3File(client, bucket, *c.Key) {
			wg.Add(1)
			go restoreFile(client, bucket, *c.Key, folder, getLasts3Path(*c.Key), encryption, keyPath, wg, ch)
		} else {
			ch <- newRestoreResult(debug, errors.New(*c.Key+" is not s3 file"))
		}
	}

	ch <- newRestoreResult(debug, nil)
}

func restoreFileSystem(client *s3.Client, s3c *S3Config, path string, backupName string, encryption bool, keyPath string, js *JobStatus) (error, error) {
	debug := errors.New("restore backup: " + backupName)

	js.setBackupFolder(path)
	ch := make(chan restoreResult, 99999)
	wg := new(sync.WaitGroup)

	pathFolder, pathFile := filepath.Split(path)
	err := os.Mkdir(pathFolder, 0755)
	if err != nil {
		if !os.IsExist(err) {
			return debug, err
		}
	}

	wg.Add(1)
	if isS3File(client, s3c.s3DestinationBucket, backupName) {
		restoreFile(client, s3c.s3DestinationBucket, backupName, pathFolder, pathFile, encryption, keyPath, wg, ch)
	} else if isS3Folder(client, s3c.s3DestinationBucket, backupName) {
		go restoreFolder(client, s3c.s3DestinationBucket, backupName, pathFolder, encryption, keyPath, wg, ch)
	} else {
		return debug, errors.New(backupName + " not found in bucket: " + s3c.s3DestinationBucket)
	}

	wg.Wait()
	close(ch)

	var results restoreResult
	for {
		result, ok := <-ch
		if ok {
			results = results.joinResult(result)
		} else {
			break
		}
	}

	js.updateDuration()
	return errors.Join(debug, results.getDebug()), results.getError()
}
