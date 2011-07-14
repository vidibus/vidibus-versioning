class Article
  include Mongoid::Document
  include Vidibus::Versioning::Mongoid

  field :title, :type => String
  field :text, :type => String
  field :published, :type => Boolean, :default => false

  versioned :title, :text, :editing_time => 300

  validates :title, :presence => true
end
