require "objectify/config/policies"
require "objectify/executor"
require "objectify/policy_chain_executor"
require "objectify/instrumentation"
require "objectify/rails/renderer"

module Objectify
  module Rails
    module ControllerHelpers
      def self.included(klass)
        klass.helper_method(:objectify_executor) if klass.respond_to?(:helper_method)
      end

      private
        def objectify
          ::Rails.application.objectify
        end

        def injector
          objectify.injector
        end

        def request_injectables_context
          klass = Objectify::Config::Injectables
          @request_injectables_context ||= klass.new.tap do |injectables_context|
            injectables_context.add_value(:controller, self)
            injectables_context.add_value(:params, params)
            injectables_context.add_value(:session, session)
            injectables_context.add_value(:cookies, cookies)
            injectables_context.add_value(:request, request)
            injectables_context.add_value(:response, response)
            injectables_context.add_value(:flash, flash)
            injectables_context.add_value(:renderer, Renderer.new(self))
          end
        end
        
        def objectify_executor
          objectify.executor
        end

        def policy_chain_executor
          @policy_chain_executor ||= Objectify::PolicyChainExecutor.new(objectify_executor, objectify)
        end

        def objectify_route
          @objectify_route ||= if params[:objectify]
            Objectify::Route.new(params[:objectify][:resource].to_sym,
                                 params[:action].to_sym)
          else
            Objectify::Route.new(params[:controller].to_sym,
                                 params[:action].to_sym)
          end
        end

        def action
          @action ||= if params[:objectify]
                        objectify.action(objectify_route)
                      else
                        objectify.legacy_action(objectify_route)
                      end
        end

        def execute_policy_chain
          policy_chain_executor.call(action)
        end

        def objectify_around_filter
          objectify.injectables.context = request_injectables_context
          yield
          objectify.injectables.context = nil
        end

        def execute_objectify_action
          service_result = objectify_executor.call(action.service, :service)
          request_injectables_context.add_value(:service_result, service_result)

          objectify_executor.call(action.responder, :responder)
        end
    end

    module LegacyControllerBehaviour
      include ControllerHelpers
      include Instrumentation

      def self.included(klass)
        klass.helper_method(:objectify_executor) if klass.respond_to?(:helper_method)
      end

      def method_missing(name, *args, &block)
        instrument("start_processing.objectify", :route => objectify_route)

        execute_objectify_action
      end
    end

    module ControllerBehaviour
      include ControllerHelpers
      include Instrumentation

      def self.included(klass)
        klass.helper_method(:objectify_executor) if klass.respond_to?(:helper_method)
      end

      def method_missing(name, *args, &block)
        instrument("start_processing.objectify", :route => objectify_route)

        if execute_policy_chain
          execute_objectify_action
        end
      end
    end

    class ObjectifyController < ActionController::Base
      include ControllerBehaviour
    end
  end
end
