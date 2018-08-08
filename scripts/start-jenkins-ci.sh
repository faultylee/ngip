#!/bin/bash -e
# This script will is to be triggered by a CI from code checkin, and check if Jenkins CI server is up, will bring it up if not, and also trigger the build on it.

if [ -e ../.env ]; then
  source ../.env
fi

source ./docker_helper.sh

function check_and_trigger_build(){
  if [[ "$(docker_run curl --connect-timeout 15 -s -o /dev/null -w ''%{http_code}'' http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/)" == "200" ]]; then

    triggered=false
    for job_url in $(docker_run curl -s http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/api/json | docker_run_i jq -r '.jobs[]? | .url'); do
      echo ${job_url}
      last_build_url=$(docker_run curl -s ${job_url/build.ngip.io/$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io}api/json | docker_run_i jq -r '.lastBuild? | .url')
      if [ -n "$last_build_url" ]; then
        commit_sha=$(curl -s "${last_build_url/build.ngip.io/$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io}api/json" | docker_run_i jq -r '.actions[]? | .lastBuiltRevision | .SHA1 | select(. != null)')
        if [ "$commit_sha" = "$TRAVIS_COMMIT" ]; then
          triggered=true
        fi
      fi
    done

    #docker_run curl -s -X POST http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/job/$TRAVIS_BRANCH/build?delay=0sec
    if [ "$triggered" = false ]; then
      docker_run curl -s -X POST http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/build?delay=0sec
    fi
    exit 0
  fi
}

function revoke_ip(){
    docker_run aws ec2 revoke-security-group-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --port 80 \
      --protocol tcp --cidr $1;
}

function authorize_ip(){
  docker_run aws ec2 authorize-security-group-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --protocol tcp \
      --port 80 \
      --cidr $IP/32

  docker_run aws ec2 update-security-group-rule-descriptions-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --ip-permissions "[{\"IpProtocol\":\"tcp\",\"FromPort\":80,\"ToPort\":80,\"IpRanges\":[{\"CidrIp\":\"$IP/32\",\"Description\":\"Travis-CI\"}]}]"
}

# Get the previous Travis-CI IP and remove from Security Group
# TODO: jq .[] | .[] | .[] is hacky, need to find out why aws cli is returning empty arrays
#docker_run aws ec2 describe-security-groups --group-ids $JENKINS_SECURITY_GROUP_ID \
#  --query "SecurityGroups[*].IpPermissions[*].IpRanges[?Description=='Travis-CI'].CidrIp" \
#  | jq -r ".[] | .[] | .[]" \
#  | while read IP; do revoke_ip $IP; done


# Add the current list of Travis-CI IP into the Security Group
#docker_run curl -s https://dnsjson.com/nat.travisci.net/A.json \
#  | jq -r '.results.records|sort | .[]' \
#  | while read IP; do authorize_ip $IP; done

# if Jenkins CI Server already running, trigger tge build straight away
check_and_trigger_build

docker_run aws ec2 start-instances --instance-ids $JENKINS_INSTANCE_ID

# Wait for Jenkins CI Server to start, should be less than 2~4 mins
counter=0
result=0
until [ $counter -ge 24 ]
do
  [[ "$(docker_run curl --connect-timeout 15 -s -o /dev/null -w ''%{http_code}'' http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/)" == "200" ]] && result=1 && break
  counter=$[$counter+1]
  printf '.'
  sleep 5
done
if [ $result -eq 0 ]; then
  echo "Jenkins CI Server failed to start"
  exit 1
fi

check_and_trigger_build
