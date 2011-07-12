require "spec_helper"

describe "Options" do
  describe "Article.versioning_options" do
    it "should be {:editing_time => 300}" do
      Article.versioning_options.should eql({:editing_time => 300})
    end
  end

  describe "Book.versioning_options" do
    it "should be {}" do
      Book.versioning_options.should eql({})
    end
  end
end