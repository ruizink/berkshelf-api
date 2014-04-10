#
# Cookbook Name:: berkshelf
# Recipe:: app
#
# Copyright (C) 2013-2014 Jamie Winsor
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "runit"

chef_gem "bundler"

if platform_family?("rhel")
  package "libarchive"
  package "libarchive-devel"
else
  package "libarchive#{node[:platform_version].split('.')[0].chomp('0')}"
  package "libarchive-dev"
end

user node[:berkshelf_api][:owner] do
  home node[:berkshelf_api][:home]
end

group node[:berkshelf_api][:group]

file node[:berkshelf_api][:config_path] do
  content JSON.generate(node[:berkshelf_api][:config].to_hash)
end

asset = github_asset "berkshelf-api.tar.gz" do
  repo node[:berkshelf_api][:repo]
  release node[:berkshelf_api][:release]
end

libarchive_file "berkshelf-api.tar.gz" do
  path asset.asset_path
  extract_to node[:berkshelf_api][:deploy_path]
  extract_options :no_overwrite
  owner node[:berkshelf_api][:owner]
  group node[:berkshelf_api][:group]

  action :extract
  notifies :restart, "runit_service[berks-api]"
  only_if { ::File.exist?(asset.asset_path) }
end

runit_service "berks-api"
