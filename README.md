# objectify [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/bitlove/objectify)

Objectify is a framework that codifies good object oriented design practices for building maintainable rails applications. For more on the motivations that led to objectify, check out this blog post: http://jamesgolick.com/2012/5/22/objectify-a-better-way-to-build-rails-applications.html

## How it works

Objectify has two primary components:

1. A request execution framework that separates the responsibilities that are typically jammed together in rails controller actions in to 3 types of components: Policies, Services, and Responders. Properly separating and assigning these responsibilities makes code far more testable, and facilitates better reuse of components.

2. A dependency injection framework. Objectify automatically injects dependencies into objects it manages based on parameter names. So, if you have a service method signature like  `PictureCreationService#call(params)`, objectify will automatically inject the request's params when it calls that method. It's very simple to create custom injections. More on that below.

---

__The flow of an objectify request is as follows:__

__1)__ Objectify actions are configured in the routes file:

```ruby
# config/routes.rb
# ... snip ...
objectify.resources :pictures
```

  Objectify currently only supports resourceful actions, but that's just a temporary thing.

__2)__ The policy chain is resolved (based on the various levels of configuration) and executed. Objectify calls the `#allowed?(...)` method on each policy in the chain. If one of the policies fails, the chain short-circuits at that point, and objectify executes the configured responder for that policy.

  An example Policy:

```ruby
class RequiresLoginPolicy
  # more on how current user gets injected below
  def allowed?(current_user)
    !current_user.nil?
  end
end
```

  A responder, in case that policy fails.

```ruby
class UnauthenticatedResponder
  def call(format, routes)
    format.any { redirect_to routes.login_url }
  end
end
```

  Here's how you setup the RequiresLoginPolicy to run by default (you can configure specific actions to ignore it), and connect the policy with its responder.

```ruby
# config/routes.rb
MyApp::Application.routes.draw do
  objectify.defaults :policies => :requires_login
  objectify.policy_responders :requires_login => :unauthenticated
end
```

__3)__ If all the policies succeed, the service for that action is executed. A service is typically responsible for fetching and / or manipulating data.

  A very simple example of a service:

```ruby
class PicturesCreateService
  # the current_user and the request's params will be automatically injected here.
  def call(current_user, params)
    current_user.pictures.create params[:picture]
  end
end
```

__4)__ Finally, the responder is executed. Following with our `Pictures#create` example:

```ruby
class PicturesCreateResponder
  # service_result is exactly what it sounds like
  def call(service_result, format)
    if service_result.persisted?
      format.any { redirect_to service_result }
    else
      # the service_result is always the only thing passed to the view
      # (hint: use a presenter)
      # you can access it with the `objectify_data` helper.
      format.any { render :template => "pictures/new.html.erb" }
    end
  end
end
```

## What if I have a bunch of existing rails code?

Objectify has a legacy mode that allows you to execute the policy chain as a `before_filter` in your ApplicationController. You can also configure policies (and `skip_policies`) for your "legacy" actions. That way, access control code is shared between the legacy and objectified components of your application.

I completely rewrote our legacy authentication system as a set of objectify policies, resolvers, and services - I'm gonna package that up and release it soon.

Here's how to run the policy chain in your ApplicationController - it'll figure out which policies to run itself:

```ruby
class ApplicationController < ActionController::Base
  include Objectify::Rails::ControllerHelpers

  around_filter :objectify_around_filter
  before_filter :execute_policy_chain
end
```

And to configure policies for a legacy action:

```ruby
# config/routes.rb
MyApp::Application.routes.draw do
  objectify.defaults :policies => :requires_login
  objectify.policy_responders :requires_login => :unauthenticated
  objectify.legacy_action :controller, :action, :policies => [:x, :y, :z],
                                                :skip_policies => [:requires_login]
end
```

Then, you need to create an ObjectifyController that inherits from ApplicationController, and configure objectify to use that:

```ruby
# app/controllers/objectify_controller.rb
class ObjectifyController < ApplicationController
  include Objectify::Rails::LegacyControllerBehaviour
end
```

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    # ...snip...
    objectify.objectify_controller = "objectify"
  end
end
```


## Custom Injections

There are a few ways to customize what gets injected when. By default, when objectify sees a parameter called `something`, it'll first look to see if something is specifically configured for that name, then it'll attempt to satisfy it by calling `Something.new`. If that doesn't exist, it'll try `SomethingResolver.new`, which it'll then call `#call` on. If that doesn't exist, it'll raise an error.

You can configure the injector in 3 ways. The first is used to specify an implemenation.

Let's say you had a PictureCreationService whose constructor took a parameter called `storage`.

```ruby
class PictureCreationService
  def initialize(storage)
    @storage = storage
  end

  # ... more code ...
end
```

You can tell the injector what to supply for that parameter like this:

```ruby
objectify.implementations :storage => :s3_storage
```

Another option is to specify a value. For example, you might have a service class with a page_size parameter.

```ruby
class PicturesIndexService
  def initialize(page_size)
    @page_size = page_size
  end

  # ... more code ...
end
```

You can tell the injector what size to make the pages like this:

```ruby
objectify.values :page_size => 20
```

Finally, you can tell objectify about `resolvers`. Resolvers are objects that know how to fulfill parameters. For example, several of the above methods have parameters named `current_user`. Here's how to create a custom resolver for it that'll automatically get found by name.

```ruby
# app/resolvers/current_user_resolver.rb
class CurrentUserResolver
  def initialize(user_finder = User)
    @user_finder = user_finder
  end

  # note that resolvers themselves get injected
  def call(session)
    @user_finder.find_by_id(session[:current_user_id])
  end
end
```

If you wanted to explicitly configure that resolver, you'd do it like this:

```ruby
objectify.resolvers :current_user => :current_user
```

If that resolver was in the namespace ObjectifyAuth, you'd configure it like this:

```ruby
objectify.resolvers :current_user => "objectify_auth/current_user"
```

### Why did you constructor-inject the User constant in to the CurrentUserResolver?

Because that makes it possible to test in isolation.

```ruby
describe "CurrentUserResolver" do
  before do
    @user        = stub("User")
    @user_finder = stub("UserFinder", :find_by_id => nil)
    @user_finder.stubs(:find_by_id).with(10).returns(@user)

    @resolver = CurrentUserResolver.new(@user_finder)
  end

  it "returns whatever the finder returns" do
    @resolver.call({:current_user_id => 42}).should be_nil
    @resolver.call({:current_user_id => 10}).should == @user
  end
end
```

### Decorators

Decorators are a great way to create truly modular and composable software. Here's a great example.

In objectify\_auth, there's a SessionsCreateService that you can use as the basis for the creat action in your /sessions resource. By default, it does very little:

```ruby
class SessionsCreateService
  def initialize(authenticator, session_creator)
    @authenticator = authenticator
    @session_creator = session_creator
  end

  def call(params, session)
    @authenticator.call(params[:email], params[:password]).tap do |user|
      @session_creator.call(session) if user
    end
  end
end
```

Let's say we wanted to add remember token issuance. We could rewrite the entire SessionsCreationService or extend (with inheritance) it to do that, but then we'd have to retest the whole unit again. A decorator allows us to avoid that:

```ruby
class SessionsCreateServiceWithRememberToken
  def initialize(sessions_create_service, remember_token_generator)
    @sessions_create_service = sessions_create_service
    @remember_token_generator = remember_token_generator
  end

  def call(params, session, cookies)
    @sessions_create_service.call(params, session).tap do |user|
      if user
        token = @remember_token_generator.call(user)
        cookies[:remember_token] = { ... }
      end
    end
  end
end
```

This makes for a very simple and easy to test extension to our SessionsCreateService. We can tell objectify to use this decorator like this:

```ruby
# config/routes.rb
objectify.decorators :sessions_create_service => :sessions_create_service_with_remember_token
```

If we wanted to specify additional decorators, it'd look like this:

```ruby
# config/routes.rb
objectify.decorators :sessions_create_service => [:sessions_create_service_with_remember_token, :sessions_create_service_with_captcha_verification]
```

## Views

Objectify has two major impacts on your views.

  1. You can only pass one variable from an objectified action to the controller. You do that by calling `renderer.data(the_object_you_want_to_pass)`. Then, you call `objectify_data` in the view to fetch the data. If it's not there, it'll raise an error. Use a presenter or some kind of other struct object to pass multiple objects to your views.

  2. You can reuse your policies in your views. `require "objectify/rails/helpers"` and add `Objectify::Rails::Helpers` to your helpers list, and you'll get a helper called `#policy_allowed?(policy_name)`. Yay code reuse.

## Installation

```ruby
# Gemfile
gem "objectify", "> 0"

# config/application.rb
module MyApp
  class Application < Rails::Application
    # only have to require this if you want objectify logging
    require "objectify/rails/log_subscriber"
    include Objectify::Rails::Application
  end
end
```

## Issues

We're using this thing in production to serve millions of requests every day. However, it's far from being complete. Here are some of the problems that still need solving:

  * Support for all the kinds of routing that rails does.
  * Caching of policy results per-request, so we don't have to run them twice if they're used in views.
  * Smarter injection strategies, and possibly caching.
  * ???

## Credits

  * Author: James Golick @jamesgolick
  * Advice (and the idea for injections based on method parameter names): Gary Bernhardt @garybernhardt
  * Feedback: Jake Douglas @jakedouglas
  * Feedback: Julie Haché @juliehache
  * The gem name: Andrew Kiellor @akiellor

## The other objectify gem

  If you were looking for the gem that *used* to be called objectify on rubygems.org, it's here: https://github.com/akiellor/objectify

## Copyright

Copyright (c) 2012 James Golick, BitLove Inc. See LICENSE.txt for
further details.
