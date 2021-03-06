require 'lotus/utils/hash'
require 'set'

module Lotus
  module Action
    # A set of params requested by the client
    #
    # It's able to extract the relevant params from a Rack env of from an Hash.
    #
    # There are three scenarios:
    #   * When used with Lotus::Router: it contains only the params from the request
    #   * When used standalone: it contains all the Rack env
    #   * Default: it returns the given hash as it is. It's useful for testing purposes.
    #
    # @since 0.1.0
    class Params
      # The key that returns raw input from the Rack env
      #
      # @since 0.1.0
      RACK_INPUT    = 'rack.input'.freeze

      # The key that returns router params from the Rack env
      # This is a builtin integration for Lotus::Router
      #
      # @since 0.1.0
      ROUTER_PARAMS = 'router.params'.freeze

      # @attr_reader env [Hash] the Rack env
      #
      # @since 0.2.0
      # @api private
      attr_reader :env

      # Initialize the params and freeze them.
      #
      # @param env [Hash] a Rack env or an hash of params.
      #
      # @return [Params]
      #
      # @since 0.1.0
      def initialize(env)
        @env    = env
        @params = _compute_params
        freeze
      end

      # Returns the object associated with the given key
      #
      # @param key [Symbol] the key
      #
      # @return [Object,nil] return the associated object, if found
      #
      # @since 0.2.0
      def [](key)
        @params[key]
      end

      # Whitelists the named parameter
      #
      # @param name [#to_sym] The name of the param to whitelist
      #
      # @return void
      #
      # @since x.x.x
      #
      # @example
      #   require 'lotus/controller'
      #
      #   class SignupParams < Lotus::Action::Params
      #     param :email
      #   end
      #
      #   params = SignupParams.new({id: 23, email: 'mjb@example.com'})
      #   params[:email] # => 'mjb@example.com'
      #   params[:id]    # => nil
      def self.param(name)
        names << name.to_sym
        nil
      end

      private

      # Returns the names of the params which have been whitelisted
      #
      # @return [Set] return the names of the whitelisted params
      #
      # @api private
      # @since x.x.x
      def self.names
        @names ||= Set.new
      end

      # Returns whether or not params are being whitelisted
      #
      # @return [TrueClass, FalseClass] return whether whitelisting is being used
      #
      # @api private
      # @since x.x.x
      def self.whitelisting?
        names.any?
      end

      def _compute_params
        Utils::Hash.new(
          _whitelist(
            _extract
          )
        ).symbolize!
      end

      def _extract
        {}.tap do |result|
          if env.has_key?(RACK_INPUT)
            result.merge! ::Rack::Request.new(env).params
            result.merge! env.fetch(ROUTER_PARAMS, {})
          else
            result.merge! env.fetch(ROUTER_PARAMS, env)
          end
        end
      end

      def _whitelist(raw_params)
        if self.class.whitelisting?
          self.class.names.reduce({}) do |params, name|
            case
            when raw_params.has_key?(name)
              params[name] = raw_params[name]
            when raw_params.has_key?(name.to_s)
              params[name] = raw_params[name.to_s]
            end
            params
          end
        else
          raw_params
        end
      end

    end
  end
end
