#!/bin/sh

# tag jar in S3

path=target/scala-2.11
newjar=Autocomplete_Index_Builder-assembly-$GO_PIPELINE_LABEL-1.0.jar

aws_path=search/autocomplete/artifacts
bucket='saks-ml'

aws sts assume-role --role-arn arn:aws:iam::326027360148:role/EMR_EC2_DefaultRole --role-session-name gocd-run-emr-etl > response.json
export AWS_SECRET_ACCESS_KEY=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
export AWS_ACCESS_KEY_ID=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
export AWS_SESSION_TOKEN=$( cat response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")
rm response.json

aws s3api put-object-tagging \
    --bucket saks-ml \
    --key search/autocomplete/artifacts/Autocomplete_Index_Builder-assembly-8-fc5bdc6-1.0.jar \
    --tagging '{"TagSet": [{ "Key": "deployed_to_prod_3", "Value": "false" }, { "Key": "deployed_to_stage_3", "Value": "false" } ]}'

