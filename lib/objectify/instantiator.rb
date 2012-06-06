require "active_support/all"

module Objectify
  class Instantiator
    def initialize(injector)
      @injector = injector
    end

    def call(name, type)
      join_char = type == :policy ? "_" : "/"
      klass = [name, type].join(join_char).classify.constantize
      @injector.call(klass, :new)
    end
  end
end
