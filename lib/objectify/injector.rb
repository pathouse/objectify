require "objectify/instrumentation"

module Objectify
  class Injector
    include Instrumentation

    attr_writer :config

    def initialize(config)
      @config = config
    end

    def call(object, method)
      payload = {:object => object, :method => method}
      instrument("inject.objectify", payload) do |payload|
        method_obj           = method_object(object, method)
        injectables          = method_obj.parameters.map do |reqd, name|
          @config.get(name) if reqd == :req
        end.compact
        arguments            = injectables.map do |type, value|
          if type == :unknown
            type, value = unknown_value_to_injectable(value)
          end

          if type == :resolver
            resolver_klass = [value, :resolver].join("_").classify.constantize
            call(call(resolver_klass, :new), :call)
          elsif type == :implementation
            implementation_klass = value.to_s.classify.constantize
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

        object.send(method, *arguments)
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

      def unknown_value_to_injectable(value)
        [nil, :resolver].each do |suffix|
          begin
            [value, suffix].compact.join("_").classify.constantize
            return [suffix.nil? ? :implementation : suffix, value]
          rescue NameError => e
          end
        end

        raise ArgumentError, "Can't figure out how to inject #{value}."
      end
  end
end
