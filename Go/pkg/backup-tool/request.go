package backuptool

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
)

func NewCurl() (*JobStatus, error) {

	reqConfig, err := getRequestConfig()
	if err != nil {
		return nil, errors.Join(errors.New("fail to get configuration: "), err)
	}

	resp, err2 := http.Get(reqConfig.getServerAddress() + "/backup")
	if err2 != nil {
		return nil, errors.Join(errors.New("request failed: "), err2)
	}

	defer resp.Body.Close()
	body, err3 := io.ReadAll(resp.Body)
	if err3 != nil {
		return nil, errors.Join(errors.New("fail to read response: "), err3)
	}

	var js JobStatus
	err4 := json.Unmarshal(body, &js)
	if err4 != nil {
		return nil, errors.Join(errors.New("fail unmarshal json: "), err4)
	}

	return &js, nil
}
