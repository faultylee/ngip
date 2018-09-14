#
# Cookbook:: middleware
# Recipe:: docker
#

docker_service 'default' do
    action [:create, :start]
end

docker_image 'faultylee/aws-cli-docker' do
    action :pull
end

docker_container 'test_curl' do
    repo 'faultylee/aws-cli-docker'
    tag 'latest'
    env 'TEST=1234'
    tty true
    command '/bin/bash -c "env && curl -L -s https://ifconfig.co/json | jq -c"'
    restart_policy 'always'
    action :run
end

