require "spec_helper"
require "objectify/instantiator"

describe "Objectify::Instantiator" do
  module My
    class Service
    end
  end

  class MyPolicy
  end

  before do
    @injector     = stub("Injector")
    @instantiator = Objectify::Instantiator.new(@injector)
  end

  context "with a service" do
    before do
      @service = My::Service.new
      @injector.stubs(:call).returns(@service)
      @result = @instantiator.call(:my, :service)
    end

    it "returns the result of injector#call" do
      @result.should == @service
    end

    it "locates the service in the supplied namespace and instantiates" do
      @injector.should have_received(:call).with(My::Service, :new)
    end
  end

  context "with a policy" do
    before do
      @policy = MyPolicy.new
      @injector.stubs(:call).returns(@policy)
      @result = @instantiator.call(:my, :policy)
    end

    it "returns the result of injector#call" do
      @result.should == @policy
    end

    it "locates the policy namespace and instantiates" do
      @injector.should have_received(:call).with(MyPolicy, :new)
    end
  end
end
