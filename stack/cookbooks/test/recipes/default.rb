#
# Cookbook:: test
# Recipe:: default
#

package 'git'
package 'tree'

docker_service 'default' do
    action [:create, :start]
end

docker_image 'faultylee/aws-cli-docker' do
    action :pull
end
