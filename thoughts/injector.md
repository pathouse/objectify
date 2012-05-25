# Rethinking the injector

Example types of injectables:

  * :current_user => A class that we need to instantiate and call #call on to get the current_user.
  * :session_min_age_function => A function value that can be injected as-is.
  * :user_finder => Sometimes a constant, sometimes the name of a class that needs to be instantiated.
  * :session_creation_service => The name of a class that gets instantiated before it gets injected.

## Decorators

Do we want to make decorators first class? My inclination is to say yes. I'd love to have something that looked like this:

objectify.decorate "objectify_auth/session_creation_service" => ["objectify_auth/session_creation_service/with_email",
                                                                 "objectify_auth/session_creation_service/with_last_pageview"]

The above would mean that in the following case:

```ruby
class ObjectifyAuth::SessionCreationService::WithEmail
  def initialize(session_creation_service)
    @session_creation_service = session_creation_service
  end

  def call(user, session)
    @session_creation_service.call(user, session)
    session[:e] = user.email
  end
end

class ObjectifyAuth::SessionCreationService::WithLastPageview
  def initialize(session_creation_service, time)
    @session_creation_service = session_creation_service
    @time = time
  end

  def call(user, session)
    @session_creation_service.call(user, session)
    session[:l] = @time.now
  end
end
```

...WithEmail's `session_creation_service` parameter would resolve to the base SessionCreationService, and WithLastPageview's `session_creation_service` parameter would resolve to the WithEmail instance.

Also, the ability to override decorations at the resource or action level:

objectify.resources :pictures, :decorate => {:picture_creation_service => :generic_service_instrumentation}

Also, injectables in general:

objectify.resources :pictures, :resolve => {:storage_service => :s3_storage_service}
objectify.resources :videos, :resolve => {:storage_service => :riak_storage_service}

## Ideas on API

```ruby
objectify.resolvers :current_user => "objectify_auth/current_user" # this would automatically append "Resolver"
objectify.injectables :session_min_age_function => lambda { 1.month.ago },
                      :user_finder => User,
                      :session_creation_service => :"objectify_auth/session_creation_service"
```

So basically we'd have resolvers (things that need to be instaniated called to get an injectable from), and injectables which are either class names that need to be instantiated (if they're symbols) or values.

Do we always need to be explicit? If there's a parameter called session_creation_service, should we automatically try to constantize that if we don't have a way to resolve it? If the answer to that question is yes (which I think it is), then should we allow people to import a namespace?

```ruby
objectify.injectable_namespace "objectify_auth"
```

If not that, then we probably need *something* or any kind of library is going to require a lot of manual configuration to get going.
