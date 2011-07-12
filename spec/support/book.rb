class Book
  include Mongoid::Document
  include Vidibus::Versioning::Mongoid

  field :title, :type => String
  field :text, :type => String

  validates :title, :presence => true
end
