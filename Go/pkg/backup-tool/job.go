package backuptool

import (
	"errors"
	"time"
)

type JobStatus struct {
	JobBeginDate time.Time
	JobDuration  time.Duration
}

type Job struct {
	Config *JobConfig
	Status *JobStatus
}

func initJob(jc *JobConfig) *Job {
	return &Job{
		Config: jc,
		Status: &JobStatus{
			JobBeginDate: time.Now(),
			JobDuration:  0,
		},
	}
}

// New setup, create, and return a Job
// A Job is a new backup
func New() (*Job, error, error) {

	jobConfig, err := getJobConfig()
	if err != nil {
		return nil, nil, errors.Join(errors.New("impossible to get job config"), err)
	}
	job := initJob(jobConfig)

	// Begin backup
	s3Client := newS3Client(job.getConfig().getS3Config())

	// For Test
	debug, err2 := backupFileSystem(s3Client, job.getConfig().getS3Config(), job.getConfig().getPath(), job.GetStatus())
	if err2 != nil {
		return nil, debug, errors.Join(errors.New("backup failed"), err2)
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

// GetConfig return the JobConfig from Job
func (j *Job) getConfig() *JobConfig {
	return j.Config
}
