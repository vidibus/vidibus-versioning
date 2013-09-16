require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$:.unshift File.expand_path('../../', __FILE__)

require 'rubygems'
require 'rspec'
require 'rr'
require 'vidibus-versioning'

require 'support/article'
require 'support/book'
require 'support/stubs'

Mongoid.configure do |config|
  config.connect_to('vidibus-versioning_test')
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid::Sessions.default.collections.
      select {|c| c.name !~ /system/}.each(&:drop)
  end
end
