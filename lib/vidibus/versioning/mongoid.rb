module Vidibus
  module Versioning
    module Mongoid
      extend ActiveSupport::Concern

      included do
        include ::Mongoid::Timestamps
        include Vidibus::Uuid::Mongoid

        has_many :versions, :as => :versioned, :class_name => 'Vidibus::Versioning::Version', :dependent => :destroy

        field :version_number, :type => Integer, :default => 1
        field :version_updated_at, :type => Time

        after_initialize :original_attributes
        after_initialize :set_version_updated_at, :unless => :version_updated_at
        before_update :reset_version_cache

        mattr_accessor :versioned_attributes, :unversioned_attributes, :versioning_options
        self.versioned_attributes = []
        self.unversioned_attributes = %w[_id _type uuid updated_at created_at version_number version_updated_at]
        self.versioning_options = {}

        # Returns the attributes that should be versioned.
        # If no versioned attributes have been defined on class level,
        # all attributes will be returned except the unversioned ones.
        def versioned_attributes
          filter_versioned_attributes(attributes)
        end
      end

      module ClassMethods

        # Defines versioned attributes and options
        #
        # Usage:
        #   versioned :some, :fields, :editing_time => 300
        #
        def versioned(*args)
          options = args.extract_options!
          self.versioned_attributes = args.map {|a| a.to_s} if args.any?
          self.versioning_options = options if options.any?
        end
      end

      # Returns a copy of this object with versioned attributes applied.
      #
      # Valid arguments are:
      #   :new       returns a new version of self
      #   :next      returns the next version of self, may be new as well
      #   :previous  returns the previous version of self
      #   48         returns version 48 of self
      #
      def version(*args)
        self.class.find(_id).tap do |copy|
          copy.apply_version!(*args)
        end
      end

      # Applies versioned attributes on this object. Returns nil.
      # For valid arguments, see #version.
      #
      def version!(*args)
        self.apply_version!(*args)
      end

      # Applies attributes of wanted version on self.
      # Stores current attributes in a new version.
      def migrate!(number = nil)
        unless number || version_cache.wanted_version_number
          raise(MigrationError, 'no version given')
        end
        if number && number != version_cache.wanted_version_number
          version!(number)
        end
        if version_cache.self_version
          raise(MigrationError, 'cannot migrate to current version')
        end

        set_original_version_obj

        self.attributes = version_attributes
        self.version_number = version_cache.wanted_version_number
        save!
      end

      # Calls #version!(:previous) and migrate!
      def undo!
        version!(:previous)
        migrate!
      end

      # Calls #version!(:next) and migrate!
      def redo!
        version!(:next)
        migrate!
      end

      # Saves the record and handles version persistence.
      def save(*args)
        return false if invalid?
        saved = persist_version
        (saved == nil) ? super(*args) : saved
      end

      # Raises a validation error if saving fails.
      def save!(*args)
        unless save(*args)
          raise(::Mongoid::Errors::Validations, self)
        end
      end

      def delete
        super if remove_version(:delete) == nil
      end

      def destroy
        super if remove_version(:destroy) == nil
      end

      # Reloads this record and applies version attributes.
      def reload_version(*args)
        reloaded_self = self.reload
        reloaded_self.version(*version_cache.version_args) if version_cache.version_args
        reloaded_self
      end

      # Returns the currently set version object.
      def version_object
        version_cache.version_obj
      end

      # Returns true if version requested is a new one.
      def new_version?
        version_obj and version_obj.new_record?
      end

      protected

      # Applies version on self. Returns nil
      def apply_version!(*args)
        raise ArgumentError if args.empty?
        set_version_args(*args)
        version_cache.self_version = (version_number == version_cache.wanted_version_number)
        return if version_cache.self_version

        self.attributes = version_attributes
        self.version_number = version_cache.wanted_version_number
        if time = version_obj.created_at
          self.updated_at = time
          self.version_updated_at = time
        end
        nil
      end

      # Returns the originial attributes of the record.
      # This method has to be called after_initialize.
      def original_attributes
        @original_attributes ||= versioned_attributes
      end

      # Returns true if versioned attributes were changed.
      def versioned_attributes_changed?
        versioned_attributes != original_attributes
      end

      # Returns original attributes with attributes of version object and wanted attributes merged in.
      # TODO: Only return attributes that are present on the object. They may have changed.
      def version_attributes
        # TODO: Setting the following line will cause DelayedJob to loop endlessly. The same should happen if an embedded document is defined as versioned_attribute!
        # original_attributes.merge(version_obj.versioned_attributes).merge(version_cache.wanted_attributes.stringify_keys!)

        # ensure nil fields are included as well
        attributes = Hash[*self.class.fields.keys.zip([]).flatten]

        # add version's attributes
        attributes = attributes.merge(version_obj.versioned_attributes)

        # take versioned attributes only
        filtered = filter_versioned_attributes(attributes)

        # add options provided with #version call
        filtered.merge(version_cache.wanted_attributes.stringify_keys!)
      end

      # Returns versioned attributes from input by
      # including defined attributes only or
      # removing unversioned ones.
      def filter_versioned_attributes(input)
        if self.class.versioned_attributes.any?
          input.only(self.class.versioned_attributes)
        else
          input.except(self.class.unversioned_attributes)
        end
      end

      # Sets instance variables used for versioning.
      # Helper method for #version
      def set_version_args(*args)
        version_cache.version_args = args
        version_cache.wanted_attributes = args.extract_options!
        num = args.first

        version_cache.wanted_version_number = case num
        when :new, 'new' then new_version_number
        when :next, 'next' then version_number + 1
        when :previous, 'previous' then version_number - 1
        else
          num.to_i
        end

        if version_cache.wanted_version_number < 1
          version_cache.wanted_version_number = 1
        end
      end

      # Finds or builds a version object containing the record's current attributes.
      def set_original_version_obj
        criteria = {:number => version_number_was}
        version_cache.original_version_obj = versions.where(criteria).first || versions.build(criteria)
        version_cache.original_version_obj.tap do |obj|
          obj.versioned_attributes = original_attributes
          obj.created_at = updated_at_was if obj.new_record?
        end
      end

      # Returns the version object:
      #
      # * If a version is wanted, that version will be selected or instantiated and returned.
      # * If an editing time has been defined which has not yet passed nil will be returned.
      # * Otherwise a new version will be instantiated.
      #
      def version_obj
        version_cache.version_obj ||= begin
          if version_cache.wanted_version_number
            obj = versions.
              where(:number => version_cache.wanted_version_number).first
            unless obj || version_cache.self_version
              # versions.to_a # TODO: prefetch versions before building a new one?
              obj = versions.build({
                :number => version_cache.wanted_version_number,
                :versioned_attributes => versioned_attributes,
                :created_at => updated_at_was
              })
            end
            obj
          else
            editing_time = self.class.versioning_options[:editing_time]
            if !editing_time || version_updated_at <= (Time.now-editing_time.to_i) || updated_at > Time.now # allow future versions
              versions.build(:created_at => updated_at_was)
            end
          end
        end
      end

      # Returns the next available version number.
      def new_version_number
        version_cache.new_version_number ||= begin
          latest_version = versions.desc(:number).limit(1).first
          ver = latest_version.number if latest_version
          [ver.to_i, version_number].max + 1
        end
      end

      # Caching object for gathering versioning data.
      # By storing this data inside a separate object, we can
      # transfer it easily to a version copy of self.
      def version_cache
        @version_cache ||= Struct.new(
          :wanted_version_number,
          :wanted_attributes,
          :new_version_number,
          :version_obj,
          :version_args,
          :original_version_obj,
          :self_version
        ).new
      end

      # Stores changes on version object.
      #
      # If #migrate! was called and original_version_obj is present, the object will be saved.
      # If #version was called and @wanted_version is present, changes will be applied to that version.
      # Otherwise a new version object will be stored with original attributes.
      #
      def persist_version
        return if new_record?
        return unless versioned_attributes_changed?
        if version_cache.original_version_obj
          version_cache.original_version_obj.save!
        elsif version_cache.wanted_version_number
          if version_obj
            saved = version_obj.update_attributes({
              :versioned_attributes => versioned_attributes,
              :created_at => updated_at
            })
          end
          return saved unless version_cache.self_version
        elsif version_obj
          version_obj.update_attributes!({
            :versioned_attributes => original_attributes
          })
          self.version_number = version_obj.number + 1
          self.version_updated_at = Time.now
        end
        nil
      end

      # Removes version object with given method.
      def remove_version(method)
        return unless version_cache.wanted_version_number
        version_obj.send(method)
      end

      # Resets instance variables used for versioning.
      def reset_version_cache
        @original_attributes = versioned_attributes
        @version_cache = nil
      end

      def set_version_updated_at
        self.version_updated_at ||= updated_at || Time.now
      end
    end
  end
end
