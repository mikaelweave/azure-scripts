# Golang Azure Function Sample

Small, bare-bones sample for running Golang on Azure functions. This sample leverages the [Azure Function Custom Handler feature](https://docs.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers) which is in preview. The Azure Function layer simply forwards requests to a simple Go webserver that is started by the function app. The reference and port for this standalone execution is defined in `src/host.json`.

The Go code for this sample is located in `src/go`. Pay careful attention to the request and return objects for the Go API - the Azure Function which calls this Go API (mostly) expects these data structures to be in a standardized format [Look here for more information](https://docs.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers#response-payload).

## Prerequisites

- Az cli ([Installation instructions](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest))
- Azure Function Core Tools ([install instructions](https://github.com/Azure/azure-functions-core-tools#installing))
- Golang
- Terraform
- *nix System

## Getting Started

- Copy `.env.sample` to `.env` inside the root of the repository and fill out the values. Load the environment variables.
- Build the Go code with the `scripts/build.sh` script
- Debug the Azure Function with `func host start` inside the `src` directory

## Deploying

- Copy `.env.sample` to `.env` inside the root of the repository and fill out the values
- Authenticate your shell with `az login`
- Deploy the function app and code with `scripts/deploy.sh`

## Resources

- [Azure docs on Function Custom Handlers](https://docs.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers)
- [Azure Function Custom Handler Blog by David Moore](https://itnext.io/write-azure-functions-in-any-language-with-the-http-worker-34d01f522bfd)
- [Sample Azure Function with Custom Handler](https://github.com/damoodamoo/azure-func-go-java)
- [Azure Functions Bindings and Schemas](https://itnext.io/azure-functions-http-worker-bindings-and-schemas-f32f126a3654)