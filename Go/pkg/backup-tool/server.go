package backuptool

import (
	"encoding/json"
	"net/http"
)

var (
	debug bool
)

func getBackup(w http.ResponseWriter, r *http.Request) {
	job, _, err := New(debug)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(job.GetStatus())
}

func NewServer(d bool) error {
	servConfig := getServerConfig()
	debug = d
	http.HandleFunc("/backup", getBackup)

	return http.ListenAndServe(servConfig.getListensAddress(), nil)
}
