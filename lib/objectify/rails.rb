module Objectify
  module Rails
    autoload :Application, "objectify/rails/application"
    autoload :Controller, "objectify/rails/controller"
    autoload :ControllerHelpers, "objectify/rails/controller"
    autoload :Helpers, "objectify/rails/helpers"
    autoload :LogSubscriber, "objectify/rails/log_subscriber"
    autoload :Railtie, "objectify/rails/railtie"
    autoload :Routes, "objectify/rails/routes"
    autoload :Routing, "objectify/rails/routing"
  end
end
