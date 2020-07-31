#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Build go code
cd ${SCRIPT_DIR}/../src
go build ./go/go-azure-action-server
cd $SCRIPT_DIR

# Build function app
#cd ${SCRIPT_DIR}/../src
#func pack
#cd $SCRIPT_DIR