package backuptool

import (
	"encoding/json"
	"net/http"
)

func getBackup(w http.ResponseWriter, r *http.Request) {
	job, _, err := New()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(job.GetStatus())
}

func NewServer() error {
	servConfig := getServerConfig()
	http.HandleFunc("/backup", getBackup)
	return http.ListenAndServe(servConfig.getListensAddress(), nil)
}
