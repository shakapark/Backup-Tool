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

func launchCurl() {
	log.Info("Launch curl backup")
}

func launchServer() {
	log.Info("Launch server backup")

	log.Fatal("Server error: ", backuptool.NewServer())
}

func launchJob() {

	log.Info("Launch job backup")
	job, jobDebug, err := backuptool.New()
	log.Debug("Job Debug: ", jobDebug)

	if err != nil {
		log.Fatal("Job failed: ", err)
	}
	log.Info(job.GetStatus().ToString())

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
		launchServer()
	case "curl":
		launchCurl()
	default:
		log.Fatal("Undefined backup-role ", filesystemBackupRole)
	}

}
