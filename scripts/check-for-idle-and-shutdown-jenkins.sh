#!/bin/bash -xe
# This script checks if the Jenkins CI server is idle or 60mis has pass since the last build, it will shutdown the server

if [ -e ../.env ]; then
  source ../.env
fi

source ./docker_helper.sh

keep_jenkins=false
message=
#for url in $(docker_run curl -s http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/api/json | docker_run jq -r ".jobs[]? | .url"); do
  #for job_url in $(docker_run curl -s "${url/build.ngip.io/$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io}api/json" | docker_run jq -r ".jobs[]? | .url"); do

  # for now only check one project
  for job_url in $(docker_run curl -s http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/api/json | docker_run_i jq -r '.jobs[]? | .url'); do
    echo ${job_url}
    last_build_url=$(docker_run curl -s ${job_url/build.ngip.io/$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io}api/json | docker_run_i jq -r ".lastBuild? | .url")
    if [ -n "$last_build_url" ]; then
      timestamp=$[($(date +%s)*1000 - $(docker_run curl -s "${last_build_url/build.ngip.io/$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io}api/json" | docker_run_i jq -r ".timestamp"))/1000]
      remaining=$[$JENKINS_SHUTDOWN_IDLE_SEC - $timestamp]
      if [ $timestamp -lt $JENKINS_SHUTDOWN_IDLE_SEC ]; then
        message="$message $last_build_url remaining time: $remaining"$'\n'
        keep_jenkins=true
      fi
    fi
  done
#done

if [ -n "$message" ]; then
  docker_run curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage --data-urlencode "text=$message" --data "chat_id=$TELEGRAM_CHAT_ID"
fi

if [ "$keep_jenkins" = false ]; then
  docker_run curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage --data-urlencode "text=Shutdown Jenkins Now" --data "chat_id=$TELEGRAM_CHAT_ID"
  docker_run aws ec2 stop-instances --instance-ids $JENKINS_INSTANCE_ID
fi