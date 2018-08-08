#!/usr/bin/bash -xe

function docker_run(){
  docker run --rm --net="host"\
    --volume $(pwd):/data \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    faulty/aws-cli-docker \
    "$@"
}

function docker_run_i(){
  docker run --rm -i --net="host"\
    --volume $(pwd):/data \
    --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    faulty/aws-cli-docker \
    "$@"
}