#!/usr/bin/env bash

wget http://build.ngip.io/jenkins/buildStatus/icon?job=ngip -O build-badge.svg

aws s3 cp build-badge.svg s3://ngip-build-output/build-badge.svg --acl public-read
