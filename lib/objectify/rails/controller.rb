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
            injectables_context.add_value(:format, objectify_response_collector)
          end
        end

        def objectify_response_collector
          @objectify_response_collector ||= ActionController::MimeResponds::Collector.new { default_response }
        end
        
        def objectify_executor
          objectify.executor
        end

        def policy_chain_executor
          @policy_chain_executor ||= Objectify::PolicyChainExecutor.new(objectify_executor, objectify)
        end

        def objectify_route
          routing_options = params[:objectify] ? params[:objectify] : {:controller => params[:controller].to_sym, :action => params[:action].to_sym}
          routing_options.merge!(:action => params[:action]) if routing_options.delete(:append_action)
          @objectify_route ||= Objectify::Route.new(routing_options)
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
          objectify_respond_if_response
        end

        def objectify_around_filter
          objectify.injectables.context = request_injectables_context
          yield
          objectify.injectables.context = nil
        end

        def execute_objectify_action
          @objectify_service_result = objectify_executor.call(action.service, :service)
          request_injectables_context.add_value(:service_result, @objectify_service_result)

          objectify_executor.call(action.responder, :responder)
          objectify_respond_if_response
        end

        def objectify_respond_if_response
          if format = request.negotiate_mime(objectify_response_collector.order)
            self.content_type ||= format.to_s
            lookup_context.freeze_formats([format.to_sym])
            instance_eval &objectify_response_collector.response_for(format)
          end
        end
    end

    module LegacyControllerBehaviour
      include ControllerHelpers
      include Instrumentation

      def self.included(klass)
        klass.helper_method(:objectify_executor) if klass.respond_to?(:helper_method)
      end

      def action_missing(name, *args, &block)
        instrument("start_processing.objectify", :route => objectify_route)

        execute_objectify_action
      end

      def controller_path
        action.resource_name
      end

      def action_name
        action.name
      end

      private
        def view_assigns
          {:_objectify_data => @objectify_service_result}
        end
    end

    module ControllerBehaviour
      include ControllerHelpers
      include Instrumentation

      def self.included(klass)
        klass.helper_method(:objectify_executor) if klass.respond_to?(:helper_method)
      end

      def action_missing(name, *args, &block)
        instrument("start_processing.objectify", :route => objectify_route)

        if execute_policy_chain
          execute_objectify_action
        end
      end

      def controller_path
        action.resource_name
      end

      def action_name
        action.name
      end

      private
        def view_assigns
          {:_objectify_data => @objectify_service_result}
        end
    end

    class ObjectifyController < ActionController::Base
      around_filter :objectify_around_filter
      include ControllerBehaviour
    end
  end
end
