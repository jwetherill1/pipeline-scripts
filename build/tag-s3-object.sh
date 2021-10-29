#!/bin/sh

# tag jar object in S3

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
      json=$(jq 'del(.TagSet[] | select(.Key == "Build"))' <<< "$json")
      json=$(jq '.TagSet += [{"Key": "Build", "Value": "'${Timestamp}'"}]' <<< "$json")
      ;;
    bw-jw-dev-etl | bw-jw-dev-etl-cron)
      json=$(jq 'del(.TagSet[] | select(.Key == "DevLastRun"))' <<< "$json")
      json=$(jq '.TagSet += [{"Key": "DevLastRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      if [ -z "$(jq '.TagSet[] | select(.Key=="DevFirstRun").Value' <<< "$json")" ]
      then
        json=$(jq '.TagSet += [{"Key": "DevFirstRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      fi
      ;;
    bw-jw-stage-etl | bw-jw-stage-etl-cron)
      json=$(jq 'del(.TagSet[] | select(.Key == "StageLastRun"))' <<< "$json")
      json=$(jq '.TagSet += [{"Key": "StageLastRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      if [ -z "$(jq '.TagSet[] | select(.Key=="StageFirstRun").Value' <<< "$json")" ]
      then
        json=$(jq '.TagSet += [{"Key": "StageFirstRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      fi
      ;;
    bw-jw-prod-etl | bw-jw-prod-etl-cron)
      json=$(jq 'del(.TagSet[] | select(.Key == "ProdLastRun"))' <<< "$json")
      json=$(jq '.TagSet += [{"Key": "ProdLastRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      if [ -z "$(jq '.TagSet[] | select(.Key=="ProdFirstRun").Value' <<< "$json")" ]
      then
        json=$(jq '.TagSet += [{"Key": "ProdFirstRun", "Value": "'${Timestamp}'"}]' <<< "$json")
      fi

      if [ -z "$(jq '.TagSet[] | select(.Key=="ProdRunCount").Value' <<< "$json")" ]
      then
        json=$(jq '.TagSet += [{"Key": "ProdRunCount", "Value": "1"}]' <<< "$json")
      else
        tagCount=$(jq '.TagSet[] | select(.Key=="ProdRunCount").Value | tonumber | .+1 '  <<< "$json")
        json=$(jq 'del(.TagSet[] | select(.Key == "ProdRunCount"))' <<< "$json")
        json=$(jq '.TagSet += [{"Key": "ProdRunCount", "Value": "'${tagCount}'"}]' <<< "$json")
      fi
      ;;
    *)
      echo "GO_PIPELINE_NAME IS ${GO_PIPELINE_NAME}"
  esac
cat <<< "$json" > final.json
aws s3api put-object-tagging  --bucket $bucket --key $aws_path/$newjar --tagging file://final.json
