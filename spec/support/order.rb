class Order
  include Mongoid::Document
  include Vidibus::Versioning::Mongoid

  field :status, :type => String

  versioned :status

  before_version_save :callback_before_version_save
  after_version_save :callback_after_version_save

  def callback_before_version_save
    true
  end

  def callback_after_version_save
    true
  end
end
