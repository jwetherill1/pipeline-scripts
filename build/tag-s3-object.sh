#!/bin/bash
# tag jar object in S3

# @param $1 AWS tag key, $2 json, $3 AWS tag value
replaceTag () {
    echo $1 $2 $3
    json=$(echo "$2" | jq 'del(.TagSet[] | select(.Key == "'$1'"))')
    json=$(echo "$json" | jq --arg output "${3}" '.TagSet += [{"Key": "'$1'", "Value": "\($output)"}]')
    echo "Replace Tag: "  $json
}

# @param $1 AWS tag key, $2 json, $3 AWS tag value
addTag () {
    if [ -z "$(echo "$2" |  jq '.TagSet[] | select(.Key=="'$1'").Value')" ]; then
        json=$(echo "$json" | jq --arg output "${3}" '.TagSet += [{"Key": "'$1'", "Value": "\($output)"}]')
    fi
}

#newjar=Autocomplete_Index_Builder-assembly-$GO_PIPELINE_LABEL-1.0.jar
newjar=Autocomplete_Index_Builder-assembly-12-33adb64-1.0.jar
aws_path=search/autocomplete/artifacts
S3_BUCKET=saks-ml

aws_creds=$( aws sts assume-role --role-arn arn:aws:iam::326027360148:role/EMR_EC2_DefaultRole --role-session-name gocd-run-emr-etl )
export AWS_SECRET_ACCESS_KEY=$( echo ${aws_creds} | jq --raw-output .Credentials.SecretAccessKey)
export AWS_ACCESS_KEY_ID=$( echo ${aws_creds} | jq --raw-output .Credentials.AccessKeyId)
export AWS_SESSION_TOKEN=$( echo ${aws_creds} | jq --raw-output .Credentials.SessionToken)

json=$(aws s3api get-object-tagging --bucket $S3_BUCKET --key $aws_path/$newjar)
json=$(echo "$json" | jq 'del(.VersionId)')

export timestamp=$(date "+%Y-%m-%d %H:%M:%S")
echo ${GO_PIPELINE_NAME}


if [[ "${GO_PIPELINE_NAME}" == "autocomplete-build" ]]; then
    echo "got here"
    replaceTag "Build" "${json}" "${timestamp}"
elif [[ "${GO_PIPELINE_NAME}" == *"dev"* ]]; then    
    replaceTag "DevLastRun" "${json}" "${timestamp}"
    addTag "DevFirstRun" "${json}" "${timestamp}" 
elif [[ "${GO_PIPELINE_NAME}" == *"stage"* ]]; then
    replaceTag "StageLastRun" "${json}" "${timestamp}"
    addTag "StageFirstRun" "${json}" "${timestamp}"
elif [[ "${GO_PIPELINE_NAME}" == *"prod"* ]]; then
    replaceTag "ProdLastRun" "${json}" "${timestamp}"
    addTag "ProdFirstRun" "${json}" "${timestamp}"
    if [ -n "$(echo "$json" | jq '.TagSet[] | select(.Key=="ProdRunCount").Value')" ]; then
        tagCount=$(echo "$json" | jq '.TagSet[] | select(.Key=="ProdRunCount").Value | tonumber | .+1 ')
        replaceTag "ProdRunCount" "${json}" "${tagCount}"
    else
        addTag "ProdRunCount" "${json}" "1"
    fi
fi
echo "GO_PIPELINE_NAME IS ${GO_PIPELINE_NAME}"
aws s3api put-object-tagging  --bucket $S3_BUCKET --key $aws_path/$newjar --tagging "$json"
