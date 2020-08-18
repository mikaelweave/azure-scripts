package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

func timerTest(w http.ResponseWriter, r *http.Request) {
	// Print information about function call
	t := time.Now()
	log.Printf("timerTest called at %d-%d-%d", t.Year(), t.Month(), t.Day())

	// Built sample response
	outputs := make(map[string]interface{})
	outputs["Test"] = []string{"tag1", "tag2"}
	returnValue := 42

	invokeResponse := InvokeResponse{Outputs: outputs, Logs: []string{"test log1", "test log2"}, ReturnValue: returnValue}

	js, err := json.Marshal(invokeResponse)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}
