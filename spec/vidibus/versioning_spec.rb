require "spec_helper"

describe Vidibus::Versioning do
  let(:article_attributes) {{:title => "title 1", :text => "text 1"}}
  let(:new_article) {Article.new(article_attributes)}
  let(:article) {Article.create(article_attributes)}

  describe "creating a versioned object" do
    before {article}

    it "should not create a version" do
      article.versions.should have(:no).versions
    end

    it "should set version number 1" do
      article.version_number.should eql(1)
    end
  end

  describe "updating a versioned object" do
    it "should create a new version if attributes were changed" do
      mock.any_instance_of(Vidibus::Versioning::Version).save {true}
      stub.any_instance_of(Vidibus::Versioning::Version).number {1}
      article.update_attributes(:title => "something")
    end

    it "should not create a version if update fails" do
      dont_allow.any_instance_of(Vidibus::Versioning::Version).save {true}
      article.update_attributes(:title => nil)
    end

    it "should not create a version unless any of the versioned attributes were changed" do
      dont_allow.any_instance_of(Vidibus::Versioning::Version).save {true}
      article.update_attributes(:title => "title 1")
    end

    context "with only one version" do
      before {article.update_attributes(:title => "title 2", :text => "text 2")}

      it "should create the first version object" do
        article.versions.should have(1).version
      end

      it "should store the previous attributes as versioned ones" do
        article.versions.last.versioned_attributes.should eql("title" => "title 1", "text" => "text 1")
      end

      it "should set 2 as version number on versioned object" do
        article.version_number.should eql(2)
      end

      it "should set 1 as version number on version object" do
        article.versions.last.number.should eql(1)
      end
    end

    context "with two versions" do
      context "and an editing time set to 300 seconds" do
        it "should have Article.versioning_options set properly" do
          Article.versioning_options[:editing_time].should eql(300)
        end

        context "an update" do
          before do
            stub_time("2011-06-25 13:10")
            article.update_attributes(:title => "title 2", :text => "text 2")
          end

          context "before editing time has passed" do
            before do
              stub_time("2011-06-25 13:11")
              article.update_attributes(:text => "text 3")
            end

            it "should update the versioned object" do
              article.text.should eql("text 3")
            end

            it "should have only one version object" do
              article.versions.should have(1).version
            end
          end

          context "after editing time has passed" do
            before do
              stub_time("2011-06-25 13:16")
              article.update_attributes(:text => "text 3")
            end

            it "should update the versioned object" do
              article.text.should eql("text 3")
            end

            it "should create the second version object" do
              article.versions.should have(2).versions
            end

            it "should store the previous attributes as versioned ones" do
              article.versions.last.versioned_attributes.should eql("title" => "title 2", "text" => "text 2")
            end

            it "should set version number 3 on versioned object" do
              article.version_number.should eql(3)
            end

            it "should set version number 2 on version object" do
              article.versions.last.number.should eql(2)
            end
          end
        end
      end
    end
  end

  describe "updating a version" do
    context "that is previous" do
      before {article.update_attributes(:title => "title 2", :text => "text 2")}

      it "should apply changes to the version" do
        article.version(1).update_attributes(:text => "new text")
        version = article.reload.version(1)
        version.text.should eql("new text")
      end

      it "should not change the versioned object" do
        article_before = article
        article.version(1).update_attributes(:text => "new text")
        article.reload.should eql(article_before)
      end

      it "should return true like regular saving would" do
        article.version(1).update_attributes(:text => "new text").should be_true
      end

      it "should perform no update if validation fails" do
        article.version(1).update_attributes(:title => nil).should be_false
        article.reload.version(1).title.should eql("title 1")
      end
    end

    context "that is current" do
      it "should apply changes to the versioned object itself" do
        article.version(1).update_attributes(:text => "new text")
        version = article.reload.version(1)
        version.text.should eql("new text")
      end

      it "should not create an additional version" do
        article.version(1).update_attributes(:text => "new text")
        article.versions.should have(:no).versions
      end
    end

    context "that has been reverted" do
      before do
        article.update_attributes(:title => "title 2", :text => "text 2")
        article.undo!
        article.redo!
      end

      it "should apply changes to the versioned object itself" do
        article.version(2).update_attributes(:text => "new text")
        article.reload.text.should eql("new text")
      end

      it "should apply changes to the version object" do
        article.version(2).update_attributes(:text => "new text")
        article.reload.versions.last.versioned_attributes["text"].should eql("new text")
      end
    end
  end

  it "should allow versioning embedded documents"

  it "should deal with related documents"
end
