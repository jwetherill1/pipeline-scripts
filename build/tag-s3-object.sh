#!/bin/bash
# tag jar object in S3
replaceTag () {
      json=$(jq 'del(.TagSet[] | select(.Key == "'$1'"))' <<< "$2")
      json=$(jq '.TagSet += [{"Key": "'$1'", "Value": "'$3'"}]' <<< "$json")
}

addFirstRunTag () {
      if [ -z "$(jq '.TagSet[] | select(.Key=="'$1'").Value' <<< "$2")" ]
      then
        json=$(jq '.TagSet += [{"Key": "'$1'", "Value": "'$3'"}]' <<< "$json")
      fi
}

newjar=Autocomplete_Index_Builder-assembly-8-fc5bdc6-1.0.jar
aws_path=search/autocomplete/artifacts
bucket='saks-ml'

aws sts assume-role --role-arn arn:aws:iam::326027360148:role/EMR_EC2_DefaultRole --role-session-name gocd-run-emr-etl > response.json
export AWS_SECRET_ACCESS_KEY=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
export AWS_ACCESS_KEY_ID=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
export AWS_SESSION_TOKEN=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")
rm response.json

json=$(aws s3api get-object-tagging --bucket ${bucket} --key "search/autocomplete/artifacts/Autocomplete_Index_Builder-assembly-8-fc5bdc6-1.0.jar")
json=$(jq 'del(.VersionId)' <<< "$json")

export Timestamp=$(date "+%Y-%m-%d:%H:%M:%S")

case "${GO_PIPELINE_NAME}" in
    bw-jw-build)
      replaceTag "Build" "${json}" "${Timestamp}"
      ;;
    bw-jw-dev-etl | bw-jw-dev-etl-cron)
      replaceTag "DevLastRun" "${json}" "${Timestamp}"
      addFirstRunTag "DevFirstRun" "${json}" "${Timestamp}"
      ;;
    bw-jw-stage-etl | bw-jw-stage-etl-cron)
      replaceTag "StageLastRun" "${json}" "${Timestamp}"
      addFirstRunTag "StageFirstRun" "${json}" "${Timestamp}"
      ;;
    bw-jw-prod-etl | bw-jw-prod-etl-cron)
      replaceTag "ProdLastRun" "${json}" "${Timestamp}"
      addFirstRunTag "ProdFirstRun" "${json}" "${Timestamp}"
      addFirstRunTag "ProdRunCount" "${json}" "1"

      if [ -n "$(jq '.TagSet[] | select(.Key=="ProdRunCount").Value' <<< "$json")" ]
      then
        tagCount=$(jq '.TagSet[] | select(.Key=="ProdRunCount").Value | tonumber | .+1 '  <<< "$json")
        json=$(jq 'del(.TagSet[] | select(.Key == "ProdRunCount"))' <<< "$json")
        json=$(jq '.TagSet += [{"Key": "ProdRunCount", "Value": "'${tagCount}'"}]' <<< "$json")
      fi
      ;;
    *)
      echo "GO_PIPELINE_NAME IS ${GO_PIPELINE_NAME}"
  esac
cat <<< "$json" > final.json
aws s3api put-object-tagging  --bucket $bucket --key "search/autocomplete/artifacts/Autocomplete_Index_Builder-assembly-8-fc5bdc6-1.0.jar" --tagging file://final.json
