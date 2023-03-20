package main

import (
	"flag"
	"os"
	"strings"

	backuptool "github.com/shakapark/Backup-Tool/pkg/backup-tool"
	log "github.com/sirupsen/logrus"
)

var (
	debug                bool
	filesystemBackupRole string
)

func init() {

	flag.BoolVar(&debug, "mode-debug", false, "Enable debug log level")
	flag.StringVar(&filesystemBackupRole, "backup-role", "job", "Role for filesystem backup with Backup-Tool [job|server|curl]")

	log.SetOutput(os.Stdout)
}

func launchJob() {

	log.Info("Launch job backup")
	job, jobDebug, err := backuptool.New()
	log.Debug("Job Debug: ", jobDebug)

	if err != nil {
		log.Fatal("Job failed: ", err)
	}

	log.Debug(job.GetStatus().ToString())

}

func main() {

	flag.Parse()

	if debug {
		log.SetLevel(log.DebugLevel)
	} else {
		log.SetLevel(log.InfoLevel)
	}

	// log.Debug("Debug log")
	// log.Info("Info log")
	// log.Error("Error log")

	switch strings.ToLower(filesystemBackupRole) {
	case "job":
		launchJob()
	case "server":
		log.Info("Launch server backup")
	case "curl":
		log.Info("Launch curl backup")
	default:
		log.Fatal("Undefined backup-role ", filesystemBackupRole)
	}

}
