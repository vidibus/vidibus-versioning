module Vidibus
  module Versioning
    class Version
      include ::Mongoid::Document
      include ::Mongoid::Timestamps
      include Vidibus::Uuid::Mongoid

      belongs_to :versioned, :polymorphic => true

      field :versioned_uuid, :type => String
      field :versioned_attributes, :type => Hash, :default => {}
      field :number, :type => Integer, :default => nil

      index :versioned_uuid
      index :number

      validates :versioned_uuid, :versioned_attributes, :presence => true

      before_validation :set_versioned_uuid
      before_create :set_number

      scope :timeline, desc(:created_at)

      def past?
        @is_past ||= created_at && created_at < Time.now
      end

      def future?
        @is_future ||= !created_at || created_at >= Time.now
      end

      protected

      def set_number
        return if number
        previous = Version.desc(:number).limit(1).first
        self.number = previous ? previous.number + 1 : 1
      end

      def set_versioned_uuid
        self.versioned_uuid = versioned.uuid
      end
    end
  end
end
