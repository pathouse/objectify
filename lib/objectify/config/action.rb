require "objectify/config/policies"
require "objectify/route"

module Objectify
  module Config
    class Action
      attr_reader :resource_name, :name, :route, :policies,
                  :service, :responder, :namespace

      def initialize(routing_opts,
                     resource_name, name, options, default_policies,
                     route_factory = Route)
        @route = route_factory.new(routing_opts)
        @resource_name = resource_name
        @name = name
        @policies = default_policies.merge(options, options[name])
        @namespace = options[:namespace] || resource_name

        if options[name]
          @service = options[name][:service]
          @responder = options[name][:responder]
        end
      end

      def service
        @service ||= [namespace, name].join("/")
      end

      def responder
        @responder ||= [namespace, name].join("/")
      end
    end
  end
end
