#!/usr/bin/env bash

if [ -e ../.env ]; then
  source ../.env
fi

docker run --rm \
--env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
--env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
--env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
garland/aws-cli-docker \
aws ec2 start-instances --instance-ids $JENKINS_INSTANCE_ID

