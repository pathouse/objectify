require "objectify/config/action"
require "objectify/config/injectables"
require "objectify/config/policies"
require "objectify/injector"
require "objectify/instantiator"
require "objectify/executor"

module Objectify
  module Config
    class Context
      DONT_RELOAD = [:@objectify_controller,
                     :@policies_factory,
                     :@action_factory].freeze

      attr_reader :policy_responders, :defaults, :actions, :policies
      attr_writer :injector, :instantiator, :executor,
                  :injectables, :objectify_controller

      def initialize(policies_factory = Policies, action_factory = Action)
        @policies_factory = policies_factory
        @action_factory   = action_factory
      end

      def policy_responders
        @policy_responders ||= {}
      end

      def append_policy_responders(responders)
        policy_responders.merge!(responders)
      end

      def policy_responder(policy)
        policy_responders[policy] ||
          raise(ArgumentError, "Can't find a responder for #{policy}.")
      end

      def policies
        @policies ||= @policies_factory.new
      end

      def append_defaults(defaults)
        @policies = @policies_factory.new(defaults)
      end

      def actions
        @actions ||= {}
      end

      def append_action(action)
        actions[action.route] = action
      end

      def action(route)
        actions[route] ||
          raise(ArgumentError, "No action matching #{route} was found.")
      end

      def legacy_action(route)
        actions[route] ||
          @action_factory.new(route.resource, route.action, {}, policies)
      end

      def injector
        @injector ||= Injector.new(injectables)
      end

      def injectables
        @injectables ||= Injectables.new
      end

      def append_values(opts)
        opts.each do |k,v|
          injectables.add_value(k, v)
        end
      end

      def append_implementations(opts)
        opts.each do |k,v|
          injectables.add_implementation(k, v)
        end
      end

      def append_resolvers(opts)
        opts.each do |k,v|
          injectables.add_resolver(k, v)
        end
      end

      def append_decorators(opts)
        opts.each do |k,v|
          injectables.add_decorators(k, v)
        end
      end

      def instantiator
        @instantiator ||= Instantiator.new(injector)
      end

      def executor
        @executor ||= Executor.new(injector, instantiator)
      end

      def objectify_controller
        @objectify_controller ||= "objectify/rails/objectify"
      end

      def reload
        instance_variables.each do |name|
          instance_variable_set(name, nil) unless DONT_RELOAD.include?(name)
        end
      end
    end
  end
end
