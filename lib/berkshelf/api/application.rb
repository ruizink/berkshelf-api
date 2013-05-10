trap 'INT' do
  Berkshelf::API::Application.shutdown
end

trap 'TERM' do
  Berkshelf::API::Application.shutdown
end

module Berkshelf::API
  # @author Jamie Winsor <reset@riotgames.com>
  module Application
    class << self
      extend Forwardable
      include Celluloid::Logger

      def_delegators :registry, :[], :[]=

      def instance
        return @instance unless @instance.nil?

        raise Celluloid::DeadActorError, "application not running"
      end

      # The Actor registry for Berkshelf::API.
      #
      # @note Berkshelf::API uses it's own registry instead of Celluloid::Registry.root to
      #   avoid conflicts in the larger namespace. Use Berkshelf::API::Application[] to access Berkshelf::API
      #   actors instead of Celluloid::Actor[].
      #
      # @return [Celluloid::Registry]
      def registry
        @registry ||= Celluloid::Registry.new
      end

      # Run the application in the foreground (sleep on main thread)
      def run
        loop do
          supervisor = run!

          sleep 0.1 while supervisor.alive?

          break if supervisor.interrupted

          error "!!! #{self} crashed. Restarting..."
        end
      end

      def run!
        @instance = Celluloid::SupervisionGroup.new(registry)
        @instance.supervise_as(:cache_manager, Berkshelf::API::CacheManager)
        @instance.supervise_as(:rest_gateway, Berkshelf::API::RESTGateway)
        @instance
      end

      def shutdown
        instance.terminate
        Celluloid.shutdown
      end
    end

    class SupervisionGroup < ::Celluloid::SupervisionGroup
      def initialize
        # TODO: AG Remove the :get_only option given to CacheBuilder
        super(Berkshelf::API::Application.registry) do |s|
          s.supervise_as :cache_manager, Berkshelf::API::CacheManager
          s.supervise_as :cache_builder, Berkshelf::API::CacheBuilder::Opscode, :args=>[:options=>{:get_only=>10}]
          s.supervise_as :rest_gateway, Berkshelf::API::RESTGateway
        end
        Berkshelf::API::CacheBuilder.start
      end
    end
  end
end
