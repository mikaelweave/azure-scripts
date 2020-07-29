package main

import (
	"encoding/json"
	"net/http"
	"os"

	"github.com/Azure/azure-sdk-for-go/profiles/latest/resources/mgmt/resources"
	"github.com/Azure/go-autorest/autorest/azure/auth"
)

func getGroupsClient() (resources.GroupsClient, error) {
	subscriptionID, exists := os.LookupEnv("SUBSCRIPTION_ID")
	var groupsClient resources.GroupsClient
	var err error

	if exists {
		groupsClient := resources.NewGroupsClient(subscriptionID)
		authorizer, err := auth.NewAuthorizerFromEnvironment()

		if err == nil {
			groupsClient.Authorizer = authorizer
			return groupsClient, nil
		}
	}

	return groupsClient, err
}

// ListGroups gets an interator that gets all resource groups in the subscription
func getResourceGroups(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var invokeResponse InvokeResponse
	outputs := make(map[string]interface{})

	groupsClient, err := getGroupsClient()

	if err == nil {
		groups, err := groupsClient.ListComplete(ctx, "", nil)

		if err == nil {
			var rgNames []string
			for _, v := range *groups.Response().Value {
				rgNames = append(rgNames, *v.Name)
			}
			outputs["ResourceGroupNames"] = rgNames

			invokeResponse = InvokeResponse{outputs, []string{"Resource group get succeeded"}, http.StatusOK}
		} else {
			invokeResponse = InvokeResponse{outputs, []string{err.Error()}, http.StatusInternalServerError}
		}
	} else {
		invokeResponse = InvokeResponse{outputs, []string{err.Error()}, http.StatusInternalServerError}
	}

	js, err := json.Marshal(invokeResponse)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}
