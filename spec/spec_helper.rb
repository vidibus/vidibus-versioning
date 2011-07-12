$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "rubygems"
require "rspec"
require "rr"
require "vidibus-versioning"

require "support/article"
require "support/book"
require "support/stubs"

Mongoid.configure do |config|
  name = "vidibus-versioning_test"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
  config.logger = nil
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/}.each(&:drop)
  end
end
