require 'zlib'
require 'archive/tar/minitar'
require 'pathname'
require 'fileutils'
include Archive::Tar

module Berkshelf::API
  module Endpoint
    class V1 < Endpoint::Base
      helpers Berkshelf::API::Mixin::Services
      version 'v1', using: :header, vendor: 'berkshelf'
      default_format :json

      rescue_from Grape::Exceptions::Validation do |e|
        body = JSON.generate({status: e.status, message: e.message, param: e.param})
        rack_response(body, e.status, "Content-type" => "application/json")
      end

      desc "list all known cookbooks"
      get 'universe' do
        if cache_manager.warmed?
          cache_manager.cache
        else
          header "Retry-After", 600
          status 503
        end
      end

      desc "health check"
      get 'status' do
        {
          status: 'ok',
          version: Berkshelf::API::VERSION,
          cache_status: cache_manager.warmed? ? 'ok' : 'warming',
          uptime: Time.now.utc - Application.start_time,
        }
      end

      desc "cookbook download"
      namespace 'cookbooks' do
        namespace ':cookbook_name', :requirements => { :cookbook_name => /.*/} do
          params do
            optional :nocache, type: Boolean
          end
          get ':cookbook_version', :requirements => { :cookbook_version => /[0-9]+\.[0-9]+\.[0-9]+/} do
#             { params: params }
            content_type 'application/octet-stream'
            header 'Content-Disposition', "attachment; filename='#{params[:cookbook_name]}-#{params[:cookbook_version]}.tar.gz'"
            cookbook_fullname = "#{params[:cookbook_name]}-#{params[:cookbook_version]}"
            cookbook_path = Dir.mktmpdir("#{cookbook_fullname}_")
            pn = Pathname.new(cookbook_path)

            # Skip cookbook download, in case of a cache hit or force cookbook download if nocache specified
            if (not File.readable?("#{pn.dirname}/#{cookbook_fullname}.tar.gz")) or params[:nocache]
              credentials = {
                server_url: Berkshelf::API::Application.config.endpoints[0].options.chef_url,
                client_name: Berkshelf::API::Application.config.endpoints[0].options.client_name,
                client_key: Berkshelf::API::Application.config.endpoints[0].options.client_key,
                ssl: {
                  verify: Berkshelf::API::Application.config.endpoints[0].options.ssl_verify
                }
              }
              # Download cookbook
              r = Ridley.new(credentials)
              r.cookbook.download(params[:cookbook_name], params[:cookbook_version], cookbook_path)
              # create tarball
              cwd = Dir.pwd
              Dir.chdir(pn.dirname)
              tgz = Zlib::GzipWriter.new(File.open("#{cookbook_fullname}.tar.gz", 'wb'))
              Minitar.pack(pn.basename, tgz)
              Dir.chdir(cwd)
            end
            # Delete tmpdir
            FileUtils.rm_r(cookbook_path)
            # Serve the binary file
            File.binread("#{pn.dirname}/#{cookbook_fullname}.tar.gz")
          end
        end
      end

    end
  end
end
