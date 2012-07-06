require "objectify/instrumentation"

module Objectify
  class Injector
    include Instrumentation

    attr_writer :config

    def initialize(config)
      @config = config
      @decoration_context = {}
    end

    def call(object, method)
      payload = {:object => object, :method => method}
      instrument("inject.objectify", payload) do |payload|
        namespace            = object.respond_to?(:name) && object.name ? object.name.underscore.split("/")[0...-1].join("/") : nil
        method_obj           = method_object(object, method)
        injectables          = method_obj.parameters.map do |reqd, name|
          @decoration_context[[namespace, name].join("/").to_sym] || @decoration_context[name] || @config.get(name) if reqd == :req
        end.compact
        arguments            = injectables.map do |type, value|
          if type == :unknown
            type, value = unknown_value_to_injectable(namespace, value)
          end

          if type == :resolver
            resolver_klass = [value, :resolver].join("_").camelize.constantize
            call(call(resolver_klass, :new), :call)
          elsif type == :implementation
            implementation_klass = value.to_s.camelize.constantize
            call(implementation_klass, :new)
          elsif type == :value
            value
          else
            raise ArgumentError, "Unknown injectable type: #{type}."
          end
        end

        payload[:parameters]  = method_obj.parameters
        payload[:injectables] = injectables
        payload[:arguments]   = arguments

        result = object.send(method, *arguments)
        if method == :new
          base_name = object.name.underscore.to_sym
          add_decoration_context(base_name, result)
          result = @config.decorators(base_name).inject(result) do |memo, decorator|
            call(decorator.to_s.camelize.constantize, :new).tap do |decorated|
              add_decoration_context(base_name, decorated)
            end
          end
          clear_decoration_context
        end

        result
      end
    end

    private
      def method_object(object, method)
        if method == :new
          object.instance_method(:initialize)
        else
          object.method(method)
        end
      end

      def unknown_value_to_injectable(namespace, value)
        [namespace, nil].uniq.each do |ns|
          [nil, :resolver].each do |suffix|
            begin
              [ns, [value, suffix].compact.join("_")].compact.join("/").camelize.constantize
              return [suffix.nil? ? :implementation : suffix, [ns, value].compact.join("/")]
            rescue NameError => e
            end
          end
        end

        raise ArgumentError, "Can't figure out how to inject #{value}."
      end

      def add_decoration_context(name, object)
        @decoration_context[name] = [:value, object]
      end

      def clear_decoration_context
        @decoration_context.clear
      end
  end
end
