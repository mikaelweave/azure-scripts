#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

# Directory with the .csproj of the function app
FUNC_CODE_DIR=$1
FUNC_CODE_DIR=${FUNC_CODE_DIR%/}

if [[ -f "${FUNC_CODE_DIR}/publish" ]]; then
    rm -rf ${FUNC_CODE_DIR}/publish
fi

if [[ -f "${FUNC_CODE_DIR}/publish.zip" ]]; then
    rm -f ${FUNC_CODE_DIR}/publish.zip
fi

dotnet build ${FUNC_CODE_DIR}/*.csproj --output ${FUNC_CODE_DIR}/publish --configuration release
zip -r ${FUNC_CODE_DIR}/publish.zip ${FUNC_CODE_DIR}/publish/*