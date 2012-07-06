require "spec_helper"
require "objectify/injector"

describe "Objectify::Injector" do
  class MyInjectedClass
    attr_reader :some_dependency

    def initialize(some_dependency)
      @some_dependency = some_dependency
    end

    def call(some_dependency)
      some_dependency
    end

    def requires_params(params)
      params
    end

    def optional_arg(asdf=true)
      "other value"
    end

    def no_args
      "value"
    end
  end

  # gotta use a fake resolver here because mocha sucks balls lolruby
  class SimpleResolver
    attr_accessor :name

    def initialize(something)
      @something = something
    end

    def call
      @something
    end
  end

  before do
    @config = stub("Config", :get => nil, :decorators => [])
    @injector = Objectify::Injector.new(@config)
  end

  context "when there aren't any parameters" do
    it "can call the method" do
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :no_args).should == "value"
    end

    it "can call a method with optional parameters" do
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :optional_arg).should == "other value"
    end
  end

  context "when there is a simple value parameter" do
    it "injects that value" do
      @config.stubs(:get).with(:params).returns([:value, 1])
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :requires_params).should == 1
    end
  end

  context "when there is a resolver param" do
    it "instantiates and calls the resolver" do
      @config.stubs(:get).with(:params).returns([:resolver, :simple])
      @config.stubs(:get).with(:something).returns([:value, :SOMETHING])
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :requires_params).should == :SOMETHING
    end
  end

  context "when there is an implementation param" do
    it "instantiates and calls the resolver" do
      @config.stubs(:get).with(:params).returns([:implementation, :simple_resolver])
      @config.stubs(:get).with(:something).returns([:value, :SOMETHING])
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :requires_params).call.should == :SOMETHING
    end
  end

  context "when there is an unconfigured resolver param" do
    it "instantiates and calls the resolver" do
      @config.stubs(:get).with(:params).returns([:unknown, :simple])
      @config.stubs(:get).with(:something).returns([:value, :SOMETHING])
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :requires_params).should == :SOMETHING
    end
  end

  context "when there is an unconfigured impl param" do
    it "instantiates and calls the resolver" do
      @config.stubs(:get).with(:params).returns([:unknown, :simple_resolver])
      @config.stubs(:get).with(:something).returns([:value, :SOMETHING])
      obj = MyInjectedClass.new(nil)
      @injector.call(obj, :requires_params).call.should == :SOMETHING
    end
  end

  class ToBeDecorated
  end

  class Decorator1
    attr_reader :to_be_decorated

    def initialize(to_be_decorated)
      @to_be_decorated = to_be_decorated
    end
  end

  class Decorator2
    attr_reader :to_be_decorated

    def initialize(to_be_decorated)
      @to_be_decorated = to_be_decorated
    end
  end

  context "decorating an object" do
    before do
      decorators = [:decorator1, :decorator2]
      @config.stubs(:decorators).with(:to_be_decorated).returns(decorators)
      @result = @injector.call(ToBeDecorated, :new)
    end

    it "decorates left to right" do
      @result.should be_instance_of(Decorator2)
      @result.to_be_decorated.should be_instance_of(Decorator1)
      @result.to_be_decorated.to_be_decorated.should be_instance_of(ToBeDecorated)

      @config.stubs(:decorators).with(:to_be_decorated).returns([])
      @injector.call(ToBeDecorated, :new).should be_instance_of(ToBeDecorated)
    end
  end

  module An
    class Service
      attr_reader :canada

      def initialize(canada)
        @canada = canada
      end
    end

    class ServiceWithStuff
      attr_reader :service

      def initialize(service)
        @service = service
      end
    end

    class ServiceWithOtherStuff
      def initialize(service, my_injected_class)
        @service = service
        @my_injected_class = my_injected_class
      end
    end

    class Canada
    end
  end

  context "within a namespace" do
    before do
      @config.stubs(:get).with(:canada).returns([:unknown, :canada])
      @result = @injector.call(An::Service, :new)
    end

    it "first searches within the namespace to fulfill the dependency" do
      @result.canada.should be_instance_of(An::Canada)
    end

    it "can decorate" do
      @config.stubs(:decorators).with(:"an/service").returns([:"an/service_with_stuff"])
      @injector.call(An::Service, :new).should be_instance_of(An::ServiceWithStuff)
    end

    it "can still look up the module chain for decorators" do
      @config.stubs(:decorators).with(:"an/service").returns([:"an/service_with_other_stuff"])
      @config.stubs(:get).with(:my_injected_class).returns([:unknown, :my_injected_class])
      @config.stubs(:get).with(:some_dependency).returns([:value, :asdf])
      @injector.call(An::Service, :new).should be_instance_of(An::ServiceWithOtherStuff)
    end
  end
end
