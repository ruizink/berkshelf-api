require 'gitlab_client'
require 'semverse'

module Berkshelf::API
  class CacheBuilder
    module Worker
      class Gitlab < Worker::Base
        worker_type 'gitlab'

        # @return [String]
        attr_reader :group, :download_url

        # @option options [String] :group
        #   the group to crawl for cookbooks
        # @option options [String] :url
        #   the api URL, usually something like https://gitlab.example.com
        # @option options [String] :private_token
        #   authentication token for accessing GitLab.
        def initialize(options = {})
          @gitlab_url           = options[:gitlab_url]
          @download_url         = options[:download_url]
          @group                = options[:group]

          api_url = @gitlab_url.chomp('/') + '/api/v3'
          token = options[:private_token]
          conn_options = { ssl: { verify: options[:ssl_verify] } }
          @connection = ::GitlabClient.new api_url, token, conn_options

          super(options)
        end

        # @return [String]
        def to_s
          friendly_name "[/groups/#{group}]"
        end

        # @return [Array<RemoteCookbook>]
        #  The list of cookbooks this builder can find
        def cookbooks
          [].tap do |cookbook_versions|
            connection.group(group).projects.each do |project|
              next unless project.public?
              log.debug "#{self}: Fetching branches from project '#{project.path}'..."
              branches = project.branches.select { |branch| branch =~ /\A([0-9][0-9.]+|master)\Z/ } # Select all X.X.X and master branches
              branches.each do |branch|
                log.debug "#{self}: Found branch '#{branch}'..."
                remote_cookbook = find_remote_cookbook(project, branch)
                cookbook_versions << remote_cookbook if remote_cookbook
              end
            end
          end
        rescue ::GitlabClient::Error => ex
          log.warn "#{self}: #{ex}"
          []
        end

        # Return the metadata of the given RemoteCookbook. If the metadata could not be found or parsed
        # nil is returned.
        #
        # @param [RemoteCookbook] remote
        #
        # @return [Ridley::Chef::Cookbook::Metadata, nil]
        def metadata(remote)
          log.debug "#{self}: Loading cookbook metadata for '#{remote.name} (#{remote.version})'..."
          load_metadata(remote.info, (remote.version == '0.0.0' ? "master" : remote.version))
        end

        private

        attr_reader :connection

        # Fetches a cookbook for a given project and branch
        #
        # @param [GitlabClient::Project] project
        # @param [String] branch
        # @return [RemoteCookbook]
        def find_remote_cookbook(project, branch)
          begin
            return nil unless cookbook_metadata = load_metadata(project.id, branch)

            log.debug "#{self}: Found cookbook '#{cookbook_metadata.name}' version '#{cookbook_metadata.version.to_s}'..."
            if (cookbook_metadata.version.to_s == branch || cookbook_metadata.version.to_s == '0.0.0' && branch == 'master')
              location_type = 'uri'
              location_path = (download_url == nil ? "#{project.web_url}/repository/archive.tar.gz?ref=#{branch}" : sprintf(download_url, cookbook_metadata.name, branch))
              remote_cookbook = RemoteCookbook.new(cookbook_metadata.name,
                                        cookbook_metadata.version,
                                        location_type,
                                        location_path,
                                        priority,
                                        project.id
                                       )
              return remote_cookbook
            else
              log.warn "Version found in metadata for #{project.full_path} (#{branch}) does not match the branch. Got #{cookbook_metadata.version}."
            end
          rescue ::GitlabClient::Error => ex
            log.warn "#{self}: Unable to load group: #{ex}"
          rescue Semverse::InvalidVersionFormat
            log.debug "#{self}: Ignoring branch #{branch}. Does not conform to semver."
          end
          nil
        end

        # Helper function for loading metadata from a particular ref in a Gitlab repository
        #
        # @param [String] project_id
        #   name of repository to load from
        # @param [String] ref
        #   reference, tag, or branch to load from
        #
        # @return [Ridley::Chef::Cookbook::Metadata, nil]
        def load_metadata(project_id, ref)
          project = connection.find_project_by_id(project_id)
          content = project.file(Ridley::Chef::Cookbook::Metadata::RAW_FILE_NAME, ref)

          cookbook_metadata = Ridley::Chef::Cookbook::Metadata.new
          cookbook_metadata.instance_eval(content)
          if cookbook_metadata.name == ''
            log.warn("#{self}: Ignoring Project id #{project_id}. Couldn't get a cookbook name from metadata.")
            nil
          else
            cookbook_metadata
          end
        rescue ::GitlabClient::NoSuchFile => ex
          log.warn("#{self}: #{ex}")
          nil
        rescue ::GitlabClient::NoSuchProject => ex
          log.warn("#{self}: #{ex}")
          nil
        rescue ::GitlabClient::Error => ex
          log.warn("#{self}: Please make sure gitlab is using version 6.6.0 or newer")
          nil
        rescue => ex
          log.warn("#{self}: Error getting metadata for project id #{project_id} with ref #{ref}: #{ex}")
          nil
        end
      end
    end
  end
end
