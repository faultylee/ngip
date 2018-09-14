#
# Cookbook:: middleware
# Recipe:: docker
#

bash 'yum_update' do
    user 'root'
    code <<-EOH
        yum update -y
    EOH
end

package 'git'
package 'tree'

include_recipe 'middleware::docker'