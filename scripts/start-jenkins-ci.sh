#!/bin/bash -xe

if [ -e ../.env ]; then
  source ../.env
fi

function check_and_trigger_build(){
  if [[ "$(docker_run curl --connect-timeout 15 -s -o /dev/null -w ''%{http_code}'' http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/)" == "200" ]]; then
    #docker_run curl -s -X POST http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/job/$TRAVIS_BRANCH/build?delay=0sec
    docker_run curl -s -X POST http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/ngip/build?delay=0sec
    exit 0
  fi
}

function docker_run(){
  docker run --rm \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    faulty/aws-cli-docker \
    $@
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
