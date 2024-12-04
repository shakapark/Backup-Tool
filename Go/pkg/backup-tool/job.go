package backuptool

import (
	"errors"
	"time"
)

type JobStatus struct {
	JobBeginDate time.Time     `json:"begindate"`
	JobDuration  time.Duration `json:"duration"`
	JobError     string        `json:"error"`
	JobDebug     string        `json:"debug"`
	BackupFolder string        `json:"backupfolder"`
}

func (js *JobStatus) setError(err error) *JobStatus {
	js.JobError = err.Error()
	return js
}
func (js *JobStatus) setDebug(d error) *JobStatus {
	js.JobDebug = d.Error()
	return js
}
func (js *JobStatus) setBackupFolder(bf string) *JobStatus {
	js.BackupFolder = bf
	return js
}

type Job struct {
	Config *JobConfig
	Status *JobStatus
}

func initJob() *Job {
	return &Job{
		Config: nil,
		Status: &JobStatus{
			JobBeginDate: time.Now(),
			JobDuration:  0,
			JobError:     "",
			JobDebug:     "",
			BackupFolder: "",
		},
	}
}

func (j *Job) setConfig(jc *JobConfig) {
	j.Config = jc
}
func (j *Job) setStatus(js *JobStatus) {
	j.Status = js
}

// New setup, create, and return a Job
// A Job is a new backup
func New(d bool) (*Job, error, error) {

	job := initJob()
	jobConfig, err := getJobConfig(d)
	if err != nil {
		status := job.GetStatus().setError(errors.Join(errors.New("impossible to get job config"), err))
		job.setStatus(status)
		return job, nil, errors.Join(errors.New("impossible to get job config"), err)
	}
	job.setConfig(jobConfig)

	// Begin backup
	s3Client := newS3Client(jobConfig.getS3Config())

	debug, err2 := backupFileSystem(s3Client, jobConfig.getS3Config(), jobConfig.getPath(), jobConfig.encryption, jobConfig.encryptionKeyPath, job.GetStatus())
	if err2 != nil {
		status := job.GetStatus().setError(errors.Join(errors.New("backup failed"), err2))
		job.setStatus(status)
		return job, debug, errors.Join(errors.New("backup failed"), err2)
	}

	retention := jobConfig.getRetention()
	if retention != 0 {
		debug2, err3 := deleteOldBackup(s3Client, jobConfig.getS3Config(), retention)
		debug = errors.Join(debug, debug2)
		if err3 != nil {
			status := job.GetStatus().setError(errors.Join(errors.New("delete old backup failed"), err3))
			job.setStatus(status)
			return job, debug, errors.Join(errors.New("delete old backup failed"), err3)
		}
	} else {
		debug = errors.Join(debug, errors.New("no retention set"))
	}

	if d {
		job.GetStatus().setDebug(debug)
	}
	return job, debug, nil
}

// GetStatus return the JobStatus from Job
func (j *Job) GetStatus() *JobStatus {
	return j.Status
}

// ToString return a string for JobStatus at format:
// "Job take <duration in sec> and begin <begin date at UNIX format>"
func (js *JobStatus) ToString() string {
	return "Job take " + js.JobDuration.String() + " and begin " + js.JobBeginDate.Format(time.UnixDate)
}

func (js *JobStatus) updateDuration() *JobStatus {
	js.JobDuration = time.Since(js.JobBeginDate)
	return js
}

// getConfig return the JobConfig from Job
// func (j *Job) getConfig() *JobConfig {
// 	return j.Config
// }
