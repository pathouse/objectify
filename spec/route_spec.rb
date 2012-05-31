require "spec_helper"
require "objectify/route"

describe "Objectify::Route" do
  context "two routes with the same path" do
    it "have the same #hash value" do
      Objectify::Route.new(:controller => :pictures, :action => :index).should ==
        Objectify::Route.new(:controller => :pictures, :action => :index)
    end
  end
end
