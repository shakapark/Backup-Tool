package main

import (
	"encoding/json"
	"flag"
	"io"
	"net/http"
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

	reqConfig, err := backuptool.GetRequestConfig()
	if err != nil {
		log.Fatal("Request failed: fail to get configuration: ", err)
	}

	resp, err2 := http.Get(reqConfig.GetServerAddress() + "/backup")
	if err2 != nil {
		log.Fatal("Request failed: request failed: ", err2)
	}

	defer resp.Body.Close()
	body, err3 := io.ReadAll(resp.Body)
	if err3 != nil {
		log.Fatal("Request failed: fail to read response: ", err3)
	}

	var js backuptool.JobStatus
	err4 := json.Unmarshal(body, &js)
	if err4 != nil {
		log.Debug("Job Status: ", js.ToString())
		log.Fatal("Request failed: fail unmarshal json: ", err4)
	}

	if resp.StatusCode != 200 {
		log.Debug("Job Status: ", js.ToString())
		log.Fatal("Request failed, wrong status code: ", resp.StatusCode)
	}
	log.Info("Job Status: ", js.ToString())
}

func launchServer() {
	log.Info("Launch server backup")

	servConfig := backuptool.GetServerConfig()
	http.HandleFunc("/backup", func(w http.ResponseWriter, r *http.Request) {

		job, jobDebug, err := backuptool.New(debug)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Error("Job Error: ", err)
		} else {
			w.WriteHeader(http.StatusOK)
		}
		log.Debug("Job Debug: ", jobDebug)
		w.Header().Set("Content-Type", "application/json")

		json.NewEncoder(w).Encode(job.GetStatus())
	})

	log.Fatal("Server error: ", http.ListenAndServe(servConfig.GetListensAddress(), nil))
	// log.Fatal("Server error: ", backuptool.NewServer(debug))
}

func launchJob() {

	log.Info("Launch job backup")
	job, jobDebug, err := backuptool.New(debug)
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

	log.Debug("Debug ON")
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
