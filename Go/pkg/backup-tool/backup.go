package backuptool

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

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

func encryptFile(file *os.File, certPath string) (*os.File, error) {
	cmd := exec.Command("openssl", "smime", "-encrypt", "-aes256", "-binary", "-outform", "DEM", certPath)

	fileInfo, err := file.Stat()
	if err != nil {
		return nil, err
	}
	fileContent := make([]byte, fileInfo.Size())
	file.Read(fileContent)
	in := bytes.NewReader(fileContent)
	out := &bytes.Buffer{}
	errs := &bytes.Buffer{}

	cmd.Stdin, cmd.Stdout, cmd.Stderr = in, out, errs

	if err2 := cmd.Run(); err2 != nil {
		if len(errs.Bytes()) > 0 {
			return nil, errors.Join(err2, errors.New(errs.String()))
		}
		return nil, err2
	}

	if strings.Contains(errs.String(), "Error") {
		return nil, errors.New(errs.String())
	}

	encryptFile, err3 := os.Create(file.Name() + ".encrypt")
	if err3 != nil {
		return nil, errors.Join(errors.New("error create encrypt file"), err3)
	}

	_, err4 := encryptFile.Write(out.Bytes())
	if err4 != nil {
		return nil, errors.Join(errors.New("error write encrypt file"), err4)
	}

	return encryptFile, nil
}

func uploadFile(client *s3.Client, bucket, path, prefix string, encryption bool, certPath string, wg *sync.WaitGroup, ch chan backupResult) {

	defer wg.Done()
	debug := errors.New("upload file: " + path)

	file, err := os.Open(path)
	if err != nil {
		ch <- newBackupResult(debug, errors.Join(errors.New("error opening file path: "+path), err))
		return
	}
	defer file.Close()

	if encryption {
		encryptFile, err3 := encryptFile(file, certPath)
		defer os.Remove(encryptFile.Name())
		if err3 != nil {
			ch <- newBackupResult(debug, errors.Join(errors.New("error encrypt file"), err3))
			return
		}
		encryptFile, err4 := os.Open(encryptFile.Name())
		if err4 != nil {
			ch <- newBackupResult(debug, errors.Join(errors.New("error opening file path: "+path), err4))
			return
		}

		fileInfo, _ := encryptFile.Stat()
		key := prefix + fileInfo.Name()

		putObjectParams := &s3.PutObjectInput{
			Bucket: &bucket,
			Key:    &key,
			Body:   encryptFile,
		}

		_, err2 := client.PutObject(context.TODO(), putObjectParams)
		if err2 != nil {
			ch <- newBackupResult(debug, errors.Join(errors.New("error upload file path: "+path), err2))
			return
		}

	} else {

		fileInfo, _ := file.Stat()
		key := prefix + fileInfo.Name()

		putObjectParams := &s3.PutObjectInput{
			Bucket: &bucket,
			Key:    &key,
			Body:   file,
		}

		_, err2 := client.PutObject(context.TODO(), putObjectParams)
		if err2 != nil {
			ch <- newBackupResult(debug, errors.Join(errors.New("error upload file path: "+path), err2))
			return
		}
	}
	ch <- newBackupResult(debug, nil)
}

func uploadFolder(client *s3.Client, bucket, path, prefix string, encryption bool, keyPath string, wg *sync.WaitGroup, ch chan backupResult) {

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
			go uploadFolder(client, bucket, path+"/"+file.Name(), prefix+"/"+file.Name(), encryption, keyPath, wg, ch)
		} else {
			uploadFile(client, bucket, path+"/"+file.Name(), prefix+"/", encryption, keyPath, wg, ch)
		}
	}
	ch <- newBackupResult(debug, nil)
}

func backupFileSystem(client *s3.Client, s3c *S3Config, path string, encryption bool, keyPath string, js *JobStatus) (error, error) {

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
		go uploadFolder(client, s3c.s3DestinationBucket, path, prefix, encryption, keyPath, wg, ch)
	} else {
		uploadFile(client, s3c.s3DestinationBucket, path, prefix+"/", encryption, keyPath, wg, ch)
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

func deleteOldBackup(client *s3.Client, s3c *S3Config, ret time.Duration) (error, error) {
	debug := errors.New("remove backup older than " + ret.Abs().String())

	prefix := "filesystem-"
	delimiter := "/"
	listObjectsParams := &s3.ListObjectsV2Input{
		Bucket:    &s3c.s3DestinationBucket,
		Prefix:    &prefix,
		Delimiter: &delimiter,
	}
	listObjectsOutput, err := client.ListObjectsV2(context.TODO(), listObjectsParams)
	if err != nil {
		return debug, errors.Join(errors.New("fail to list folder"), err)
	}

	var folders []string
	debug = errors.Join(debug, errors.New("list folder: "))
	for _, object := range listObjectsOutput.CommonPrefixes {
		date, err2 := time.Parse("02-01-2006", strings.TrimPrefix(strings.TrimSuffix(*object.Prefix, "/"), prefix))
		if err2 != nil {
			return debug, errors.Join(errors.New("fail to parse date name in folder name"), err2)
		}
		if date.Before(time.Now().Add(ret)) {
			debug = errors.Join(debug, errors.New(*object.Prefix))
			folders = append(folders, *object.Prefix)
		}
	}

	if len(folders) == 0 {
		debug = errors.Join(debug, errors.New("no backup need to be delete"))
	} else {
		// var objects []types.ObjectIdentifier
		debug = errors.Join(debug, errors.New("object list to delete: "))
		for _, folder := range folders {
			listObjectsParams2 := &s3.ListObjectsV2Input{
				Bucket: &s3c.s3DestinationBucket,
				Prefix: &folder,
			}
			listObjectsOutput2, err3 := client.ListObjectsV2(context.TODO(), listObjectsParams2)
			if err3 != nil {
				return debug, errors.Join(errors.New("fail to list file in folder "+folder), err3)
			}
			for _, object := range listObjectsOutput2.Contents {
				// objects = append(objects, types.ObjectIdentifier{
				// 	Key: object.Key,
				// })
				deleteObjectParams := &s3.DeleteObjectInput{
					Bucket: &s3c.s3DestinationBucket,
					Key:    object.Key,
				}

				debug = errors.Join(debug, errors.New("  -> "+*object.Key))
				_, err5 := client.DeleteObject(context.TODO(), deleteObjectParams)
				if err5 != nil {
					return debug, errors.Join(errors.New("fail to delete object: "+*object.Key), err5)
				}
			}
		}

		// deleteObjectsParams := &s3.DeleteObjectsInput{
		// 	Bucket: &s3c.s3DestinationBucket,
		// 	Delete: &types.Delete{
		// 		Objects: objects,
		// 	},
		// }
		// _, err4 := client.DeleteObjects(context.TODO(), deleteObjectsParams)
		// if err4 != nil {
		// 	return debug, errors.Join(errors.New("fail to delete objects "), err4)
		// }
	}

	return debug, nil
}
