# responders

Currently responders collaborate with other objects to actually initiate the response. They're by far the weakest abstraction in objectify. This document contains some thoughts on how to fix that.

## Value objects approach

Bryan Helmkamp's proposal on the mailing list was to have responders return value objects that describe the response, and then objectify could use those descriptors to actually fire the response using rails' APIs.

An example:

```ruby
class SessionNewResponder
  def call
    Objectify::Render::Template.new(:name => "new.html.erb")
  end
end
```

There are two problems with this. First of all, typing out the whole namespace is cumbersome. Though, that can be solved with one `include`.

```ruby
class SessionNewResponder
  include Objectify::Render

  def call
    Template.new(:name => "new.html.erb")
  end
end
```

The second problem is how to handle multiple formats. One idea is to use the rails block syntax:

```ruby
class SessionNewResponder
  include Objectify::Render

  def call(service_result)
    FormattedResponse.new(:data => service_result) do |format|
      format.html
      format.js
    end
  end
end
```

Or something like that. I'm not a huge fan of that syntax because it seems difficult to test, although maybe that's solved by making the result of the little DSL very simple.

```ruby
class SessionNewResponder
  include Objectify::Render

  def call(service_result)
    FormattedResponse.new(:data => service_result) do |format|
      format.html Template.new("somewhere.html.erb")
      format.js
    end
  end
end
```

After writing this, I'm starting to think it's the right approach.

## Other approaches?

* Something that can be tested mockist-style, perhaps? I have no idea what this would look like, though, really.
