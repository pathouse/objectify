require "action_dispatch"
require "objectify/config/action"

module Objectify
  module Rails
    module Routing
      RESOURCE_ACTIONS = [:index, :show, :new, :create,
                          :edit, :update, :destroy].freeze
      OBJECTIFY_OPTIONS = [:policies, :service].freeze

      class ObjectifyMapper
        def initialize(rails_mapper,
                       application = ::Rails.application,
                       action_factory = Config::Action)
          @rails_mapper = rails_mapper
          @application = application
          @action_factory = action_factory
        end

        def resources(*args)
          options           = args.extract_options!
          objectify_options = extract_objectify_options(options)
          controller        = @application.objectify.objectify_controller
          rails_options     = options.merge(:controller => controller)

          args.each do |resource_name|
            objectify_defaults = {:resource => resource_name}
            merged_defaults = merge_defaults(objectify_defaults.merge(:append_action => true),
                                             rails_options)
            @rails_mapper.resources(resource_name, merged_defaults)
            RESOURCE_ACTIONS.each do |action_name|
              append_action(objectify_defaults.merge(:action => action_name),
                            resource_name,
                            action_name,
                            objectify_options)
            end
          end
        end

        def match(options)
          from,to = options.detect { |k,v| k.is_a?(String) }
          resource,action = to.split("#").map(&:to_sym)
          controller = @application.objectify.objectify_controller
          objectify_options = extract_objectify_options(options)
          objectify_defaults = {"path" => from.dup}
          rails_options = merge_defaults(objectify_defaults, options)
          @rails_mapper.match rails_options.merge(from => "#{controller}#action")

          append_action(objectify_defaults, resource, action, objectify_options)
        end

        def defaults(options)
          @application.objectify.append_defaults(options)
        end

        def policy_responders(options)
          @application.objectify.append_policy_responders(options)
        end

        def implementations(options)
          @application.objectify.append_implementations(options)
        end

        def resolvers(options)
          @application.objectify.append_resolvers(options)
        end

        def values(options)
          @application.objectify.append_values(options)
        end

        def decorators(options)
          @application.objectify.append_decorators(options)
        end

        def legacy_action(controller, actions, options)
          [*actions].each do |action_name|
            routing_opts = {:controller => controller,
                            :action     => action_name}
            append_action(routing_opts, controller, action_name, options)
          end
        end

        private
          def extract_objectify_options(options)
            Hash[*(RESOURCE_ACTIONS + OBJECTIFY_OPTIONS).map do |key|
              [key, options.delete(key)] if options.include?(key)
            end.compact.flatten]
          end

          def merge_defaults(objectify_defaults, rails_options)
            defaults = {:objectify => objectify_defaults}
            defaults = (rails_options[:defaults] || {}).merge(defaults)
            defaults = rails_options.merge(:defaults => defaults)
          end

          def append_action(routing_opts, resource_name, action_name, options)
            action = @action_factory.new(routing_opts,
                                         resource_name,
                                         action_name,
                                         options,
                                         @application.objectify.policies)

            @application.objectify.append_action(action)
          end
      end

      class Mapper < ActionDispatch::Routing::Mapper
        def objectify
          @objectify ||= ObjectifyMapper.new(self)
        end
      end

      class RouteSet < ActionDispatch::Routing::RouteSet
        def draw(&block)
          clear! unless @disable_clear_and_finalize

          mapper = Mapper.new(self)
          if block.arity == 1
            mapper.instance_exec(ActionDispatch::Routing::DeprecatedMapper.new(self), &block)
          else
            mapper.instance_exec(&block)
          end

          finalize! unless @disable_clear_and_finalize

          nil
        end
      end
    end
  end
end
