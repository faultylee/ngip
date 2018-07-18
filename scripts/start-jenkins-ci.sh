#!/bin/bash -e

if [ -e ../.env ]; then
  source ../.env
fi

# Get the previous Travis-CI IP and remove from Security Group
IP=$(aws ec2 describe-security-groups --group-ids $JENKINS_SECURITY_GROUP_ID --query "SecurityGroups[*].IpPermissions[*].IpRanges[?Description=='Travis-CI'].CidrIp" --output text)

if [ -n $IP ]; then
  docker run --rm \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    garland/aws-cli-docker \
    aws ec2 revoke-security-group-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --port 80 \
      --protocol tcp --cidr $IP;
fi

# Add the current Travis-CI IP into the Security Group
IP=$(curl -s ifconfig.co)
if [ -n $IP ]; then
  docker run --rm \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    garland/aws-cli-docker \
    aws ec2 authorize-security-group-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --protocol tcp \
      --port 80 \
      --cidr $IP/32

  docker run --rm \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    garland/aws-cli-docker \
    aws ec2 update-security-group-rule-descriptions-ingress \
      --group-id $JENKINS_SECURITY_GROUP_ID \
      --ip-permissions "[{\"IpProtocol\": \"tcp\", \"FromPort\": 80, \"ToPort\": 80, \"IpRanges\": [{\"CidrIp\": \"$IP/32\", \"Description\": \"Travis-CI\"}]}]"

else
  echo "Cannot get IP for this server"
  exit 1
fi

# if Jenkins CI Server already running, trigger tge build straight away
check_and_trigger_build

docker run --rm \
  --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  garland/aws-cli-docker \
  aws ec2 start-instances --instance-ids $JENKINS_INSTANCE_ID


# Wait for Jenkins CI Server to start, should be less than 2~4 mins
counter=0
result=0
until [ $counter -ge 24 ]
do
  [[ "$(curl --connect-timeout 5 -s -o /dev/null -w ''%{http_code}'' http://build.ngip.io/jenkins) --user $NGIP_BUILD_USER" == "302" ]] && result=1 && break
  counter=$[$counter+1]
  printf '.'
  sleep 5
done
if [ $result -eq 0 ]; then
  echo "Jenkins CI Server failed to start"
  exit 1
fi

check_and_trigger_build

function check_and_trigger_build(){
  if [[ "$(curl --connect-timeout 5 -s -o /dev/null -w ''%{http_code}'' http://build.ngip.io/jenkins) --user $NGIP_BUILD_USER" == "302" ]]; then
    curl -s http://build.ngip.io/jenkins/job/ngip/build?token=hfw8yF34JWsWAPnBZDzItipoio1z1OgI --user $NGIP_BUILD_USER
    exit 0
  fi
}
