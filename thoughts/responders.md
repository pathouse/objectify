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

## Rename to "Responses"?

One idea I had this weekend, was to rename responders to responses. That way, conceptually, you're defining a type of response. I think that might be easier for people to think about.

Also, I think we should use methods to respond to different content types. Can't believe it took me this long to think of this.

```ruby
class UnauthorizedResponse
  include Objectify::Response

  respond_with :html, :js
  status 403

  def js
    :default
  end

  def any(service_result, renderer)
    renderer.template :name => "unauthorized.html.erb", :data => service_result
  end
end
```

```ruby
class PicturesCreateSuccessfulResponse
  include Objectify::Response

  when_policy :create_successful
  respond_with :html, :js, :json

  def html(service_result, renderer)
    responder.redirect_to service_result
  end

  def js(service_result, renderer)
    responder.redirect_to "xyz"
  end
end

class PicturesCreateUnsuccessfulResponse
  include Objectify::Response

  when_not_policy :create_successful
  respond_with :html, :js, :json

  def html(service_result, renderer)
    responder.redirect_to service_result
  end

  def js(service_result, renderer)
    responder.redirect_to "xyz"
  end
end

class PicturesCreateResponse < Objectify::Response
  respond do |service_result, format|
    if service_result.persisted?
      format.html { redirect_to service_result }
      format.js   { render :template => "pictures/show.json.json_builder" }
      format.json { render :template => "pictures/show.json.json_builder" }
    else
      format.html { render :template => "pictures/new.html.erb" }
      format.js   { render :json => { :errors => service_result.errors, :status => :unprocessable_entity } }
      format.json { render :template => "pictures/show.json.json_builder" }
    end
  end
end
```

Tests?

```ruby
describe "PicturesCreateResponse" do
  before do
    @format   = Objectify::FakeFormat.new
    @response = PicturesCreateResponse.new
  end

  context "when create is successful" do
    before do
      @service_result = stub("Result", :persisted? => true)
      @response.respond(@service_result, @format)
    end

    it "renders a template called 'pictures/new.html.erb' for html" do
      @response.should render_template("pictures/new.html.erb")
    end
  end
end
```

## Other approaches?

* Something that can be tested mockist-style, perhaps? I have no idea what this would look like, though, really.
