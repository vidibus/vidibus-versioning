# Vidibus::Versioning [![](http://travis-ci.org/vidibus/vidibus-versioning.png)](http://travis-ci.org/vidibus/vidibus-versioning) [![](http://stillmaintained.com/vidibus/vidibus-versioning.png)](http://stillmaintained.com/vidibus/vidibus-versioning)

Vidibus::Versioning provides advanced versioning for Mongoid models including support for future and editable versions.

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.


## Installation

Add `gem "vidibus-versioning"` to your Gemfile. Then call `bundle install` on your console.


## Usage

To apply versioning to your model is easy. An example:

```ruby
class Article
  include Mongoid::Document
  include Vidibus::Uuid::Mongoid
  include Vidibus::Versioning::Mongoid # this is mandatory

  field :title, :type => String
  field :text, :type => String

  versioned :title, :text, :editing_time => 300 # this is optional
end
```

### Versioned attributes

Including the versioning engine by adding `include Vidibus::Versioning::Mongoid` will set all fields of your model as
versioned ones, except those contained in `Article.unversioned_attributes`, which are `_id`, `_type`, `uuid`,
`updated_at`, `created_at`, and `version_number`.

An optional `versioned` call lets you specify the versioned attributes precisely by providing a list. For example, to
set the title as only attribute to be versioned, call `versioned :title`.


### Combined versioning

`versioned` also takes options to tweak versioning behaviour. By calling `versioned :editing_time => 300` you set a
timespan for the version to accept changes so all changes within 300 seconds will be treated as one version.
That behaviour is especially useful if your model's UI allows changing attributes separately, like in-place editing.


### Migrating

The basic methods for migrating a versioned object - an article in this case - are:

```ruby
article.migrate!(32) # migrates to version 32
article.undo!        # restores previous version
article.redo!        # restores next version
```


### Version editing

There is also a method `version` that loads an exisiting version of the record or instantiates a new one:

```ruby
article.version(3)         # returns version 3 of the article
article.version(:previous) # returns the previous version of the article
article.version(:next)     # returns the next version of the article
article.version(:new)      # returns a new version of the article
```

To apply a version on the current article itself (without persisting it), call `version` with a bang!:

```ruby
article.version!(3) # applies version 3 to the article and returns nil
```

It is even possible to apply versioned attributes directly by adding them to the `version` call:

```ruby
article.version(3, :title => "Wicked!") # returns version 3 with a new title applied
```

You may treat the article object with an applied version like the article itself. All changes will
be applied to the loaded version instead of the current instance. This is useful for creating future versions
that can be scheduled by [Vidibus::VersionScheduler](https://github.com/vidibus/vidibus-version_scheduler).

A workflow example:

```ruby
article = Article.create(:title => "Old shit")
future_article = article.version(:new)  # initialize a new version
future_article.updated_at = 1.day.since # set a date in the future
future_article.title = "New shit"       # set the new title
future_article.save                     # save the version
```


### Version objects

All versions of your models are stored in a separate model: `Vidibus::Versioning::Version`. To access the
version object of an article's version, call `article.version_object`:

```ruby
article.version(3).version_object # => #<Vidibus::Versioning::Version ... >
article.version_object            # => nil
```


## TODO

* Handle embedded documents
* Handle related documents


## Copyright

Copyright (c) 2011 Andre Pankratz. See LICENSE for details.
