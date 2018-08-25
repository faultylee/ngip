#
# Cookbook:: test
# Recipe:: default
#

package 'git'
package 'tree'

docker_service 'default' do
    action [:create, :start]
end

docker_image 'faulty/aws-cli-docker' do
    action :pull
end
