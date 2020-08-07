#!/bin/bash

buildSignature () {
    local customerId="${1}"
    local sharedKey="${2}"
    local date="${3}"
    local contentLength="${4}"
    local method="${5}"
    local contentType="${6}"
    local resource="${7}"

    local xHeaders="x-ms-date:${date}"
    local string_to_sign="${method}\n${contentLength}\n${contentType}\n${xHeaders}\n${resource}"
    #printf "$string_to_sign"

    if [ "$(uname)" == "Darwin" ]; then
        local decoded_hex_key="$(echo -n $sharedKey | base64 -d | xxd -p -c256)"
        local signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64)
        echo "SharedKey ${customerId}:${signature}"
    else
        local decoded_hex_key="$(echo -n $sharedKey | base64 -d -w0 | xxd -p -c256)"
        local signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)
        echo "SharedKey ${customerId}:${signature}"
    fi
}

postLogAnalyticData() {
    local customerId="${1}"
    local sharedKey="${2}"
    local logType="${3}"
    local timeStampField="${4}"
    local rfc1123date="$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")"
    local body="${5}"

    local method="POST"
    local contentType="application/json"
    local resource="/api/logs"
    local contentLength=${#body}

    curl -v -d "$body" \
    -H "x-ms-date: ${rfc1123date}" \
    -H "time-generated-field: ${timeStampField}" \
    -H "Log-Type: ${logType}" \
    -H "Authorization: $(buildSignature $customerId $sharedKey "$rfc1123date" $contentLength $method $contentType $resource)" \
    -H "Content-Type: application/json" \
    "https://${customerId}.ods.opinsights.azure.com${resource}?api-version=2016-04-01"
}

# Log Analytics Workspace Information - Should be pushed in as env vars when not testing
customerId="<Insert Log Analytics Customer Id>"
sharedKey="<Insert Log Analytics Shared Key"

# Data to post to custom table - should be JSON
body="$(jq -n \
                  --arg type "CurrentTemp" \
                  --arg value 341 \
                  --arg date "$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")" \
                  '{DataPointType:$type, DataPointValue:$value, DateValue:$date}')"
# Name of custom table
logType="WeatherType"
timeStampField="DateValue"

postLogAnalyticData $customerId $sharedKey $logType $timeStampField "$body"
