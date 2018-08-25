name 'test'
description 'Installs/Configures test'
version '0.1.0'
chef_version '>= 12.14' if respond_to?(:chef_version)

depends 'docker'

