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

if [ -z "$2" ]
then
    ZIP_PATH="${FUNC_CODE_DIR}/publish.zip"
else
    ZIP_PATH=$2
fi

if [[ -f "$ZIP_PATH" ]]; then
    rm -f $ZIP_PATH
fi

dotnet build ${FUNC_CODE_DIR}/*.csproj --output ${FUNC_CODE_DIR}/publish --configuration release

cd ${FUNC_CODE_DIR}/publish
zip -r $ZIP_PATH *
cd -