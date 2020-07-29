package main

import (
	"encoding/json"
	"net/http"

	"github.com/Azure/azure-sdk-for-go/profiles/preview/preview/resources/mgmt/managementgroups"
	"github.com/Azure/go-autorest/autorest/azure/auth"
)

func getManagementGroupsClient() (managementgroups.Client, error) {
	managementGroupsClient := managementgroups.NewClient("", nil, nil, "")
	authorizer, err := auth.NewAuthorizerFromEnvironment()

	if err == nil {
		managementGroupsClient.Authorizer = authorizer
		return managementGroupsClient, nil
	}

	return managementGroupsClient, err
}

func getManagementGroup(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var invokeResponse InvokeResponse
	outputs := make(map[string]interface{})

	managementClient, err := getManagementGroupsClient()

	// Get scope from URL
	queryParams := r.URL.Query()
	managementGroupID := ""
	for k, v := range queryParams {
		if k == "managementGroupId" {
			managementGroupID = v[0]
		}
	}
	if len(managementGroupID) == 0 {
		http.Error(w, "No managementGroupId provided", http.StatusBadRequest)
		return
	}

	if err == nil {
		group, err := managementClient.Get(ctx, managementGroupID, "", nil, "", "")

		if err == nil {
			outputs["Data"] = group

			invokeResponse = InvokeResponse{outputs, []string{"Management group get succeeded"}, http.StatusOK}
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
