class Comment
  include Mongoid::Document
  include Vidibus::Versioning::Mongoid

  field :text, :type => String
  field :author, type: String

  versioned :text

  validates :text, :presence => true
end
