module Objectify
  module Config
    class Injectables
      attr_reader :config
      attr_writer :context

      def initialize(config = {})
        @config = config
      end

      def add_resolver(name, value)
        @config[name] = [:resolver, value]
      end

      def add_value(name, value)
        @config[name] = [:value, value]
      end

      def add_implementation(name, value)
        @config[name] = [:implementation, value]
      end

      def get(name)
        @config[name] || context[name] || [:unknown, name]
      end

      def context
        @context && @context.config || {}
      end

      def merge(other)
        self.class.new @config.merge(other.config)
      end
    end
  end
end
