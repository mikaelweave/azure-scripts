package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

func tagResources(w http.ResponseWriter, r *http.Request) {
	t := time.Now()
	ua := r.Header.Get("User-Agent")
	ii := r.Header.Get("X-Azure-Functions-InvocationId")
	log.Printf("Tag Resources called at %d-%d-%d from user agent %s with invocation id %s", t.Year(), t.Month(), t.Day(), ua, ii)

	// Built sample response
	outputs := make(map[string]interface{})
	outputs["Test"] = []string{"tag1", "tag2"}

	invokeResponse := InvokeResponse{outputs, []string{"GO: Sent items - somewhere!"}, http.StatusOK}

	js, err := json.Marshal(invokeResponse)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}
