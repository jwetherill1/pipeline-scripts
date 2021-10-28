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

#aws s3api put-object --bucket $bucket --key $aws_path/$newjar --body $path/$newjar --grant-full-control id="46b085a8a19b045302498d68f3c1eb4c467f05759246543d1c4ecf140411e49e"

aws s3api get-object-tagging --bucket ${bucket} --key ${aws_path}/${new_jar} > CurrentTags.json

jq 'del(.VersionId)' CurrentTags.json > RemoveVersion.json

case "${GO_PIPELINE_NAME}" in
    bw-jw-build)
      export BuildTimestamp=$(date "+%Y-%m-%d:%H:%M:%S")
      export BuiltBy=${GO_TRIGGER_USER}
#      jq '.TagSet += [{"Key": "BuildTimeStamp", "Value": "'${BuildTimestamp}'"},{"Key": "BuiltBy", "Value": "'${BuiltBy}'"}]' RemoveVersion.json > AddedKey.json
      jq '.TagSet += [{"Key": "BuildTimeStamp", "Value": "'${BuildTimestamp}'"}]' RemoveVersion.json > AddedKey.json
      ;;
    bw-jw-dev-etl)
      ;;
    bw-jw-stage-etl)
      ;;
    bw-jw-stage-etl-cron)
      ;;
    bw-jw-prod-etl)
      ;;
    bw-jw-prod-etl-cron)
      ;;
    *)
      echo "GO_PIPELINE_NAME IS ${GO_PIPELINE_NAME}"
  esac

aws s3api put-object-tagging  --bucket $bucket --key $aws_path/$newjar --tagging file://AddedKey.json


