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
    @config = stub("Config", :get => nil)
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
end
