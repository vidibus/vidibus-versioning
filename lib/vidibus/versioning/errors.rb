module Vidibus
  module Versioning
    class Error < StandardError; end
    class MigrationError < Error; end
    class VersionNotFoundError < Error; end
  end
end
