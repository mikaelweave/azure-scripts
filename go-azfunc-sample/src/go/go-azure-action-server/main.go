package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	httpInvokerPort, exists := os.LookupEnv("FUNCTIONS_HTTPWORKER_PORT")
	if exists {
		log.Println("FUNCTIONS_HTTPWORKER_PORT: " + httpInvokerPort)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/setResourcesTags", tagResources)
	mux.HandleFunc("/getResourcesTags", getResourcesTags)
	mux.HandleFunc("/getResourceGroups", getResourceGroups)
	mux.HandleFunc("/getManagementGroup", getManagementGroup)
	log.Println("Go server Listening...on httpInvokerPort:", httpInvokerPort)
	log.Fatal(http.ListenAndServe(":"+httpInvokerPort, mux))
}
