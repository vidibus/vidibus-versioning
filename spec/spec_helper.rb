require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$:.unshift File.expand_path('../../', __FILE__)

require 'rubygems'
require 'rspec'
require 'rr'
require 'vidibus-versioning'
require 'database_cleaner'

Dir['spec/support/**/*.rb'].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to('vidibus-versioning_test')
  config.identity_map_enabled = true
end

RSpec.configure do |config|
  config.mock_with :rr
  # config.before(:each) do
  #   Mongoid::Sessions.default.collections.
  #     select {|c| c.name !~ /system/}.each(&:drop)
  # end
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
