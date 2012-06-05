module Objectify
  module Rails
    class Routes
      include ::Rails.application.routes.url_helpers
    end
  end
end
