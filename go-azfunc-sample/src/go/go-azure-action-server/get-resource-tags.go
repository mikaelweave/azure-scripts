package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/Azure/azure-sdk-for-go/services/resources/mgmt/2019-05-01/resources"
	"github.com/Azure/go-autorest/autorest/azure/auth"
)

func getResourcesClient() (resources.Client, error) {
	// Get subscription from env
	subscriptionID, exists := os.LookupEnv("SUBSCRIPTION_ID")
	var resourcesClient resources.Client
	var err error

	if exists {
		resourcesClient = resources.NewClient(subscriptionID)
		authorizer, err := auth.NewAuthorizerFromEnvironment()

		if err == nil {
			resourcesClient.Authorizer = authorizer
			return resourcesClient, nil
		}
	}

	return resourcesClient, err
}

func getResourcesTags(w http.ResponseWriter, r *http.Request) {
	// Print information about function call
	t := time.Now()
	ua := r.Header.Get("User-Agent")
	ii := r.Header.Get("X-Azure-Functions-InvocationId")
	log.Printf("Get Resources called at %d-%d-%d from user agent %s with invocation id %s", t.Year(), t.Month(), t.Day(), ua, ii)

	// Get scope from URL
	queryParams := r.URL.Query()
	scope := ""
	for k, v := range queryParams {
		if k == "scope" {
			scope = v[0]
		}
	}
	if len(scope) == 0 {
		http.Error(w, "No scope provided", http.StatusBadRequest)
		return
	}

	//resourceClient, err := getResourcesClient()
	//if err != nil {
	//	http.Error(w, err.Error(), http.StatusInternalServerError)
	//	return
	//}

	//resourceClient.Get(ctx, )

	//w.Header().Set("Content-Type", "application/json")
	//w.Write(js)

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
