#!/usr/bin/env bash

wget -O build.log --auth-no-challenge http://$JENKINS_API_USERNAME:$JENKINS_API_TOKEN@build.ngip.io/jenkins/job/$NGIP_BUILD_URL/consoleText

wget http://build.ngip.io/jenkins/buildStatus/icon?job=ngip -O build-badge.svg

aws s3 cp build-badge.svg s3://ngip-build-output/build-badge.svg --acl public-read

aws s3 cp build.log s3://ngip-build-output/build.log --acl public-read --content-type "text/plain"
