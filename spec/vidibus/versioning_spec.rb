require 'spec_helper'

describe Vidibus::Versioning do
  let(:article) do
    Article.create(:title => 'title 1', :text => 'text 1')
  end
  let(:book) do
    Book.create(:title => 'title 1', :text => 'text 1')
  end

  describe 'creating a versioned object' do
    before do
      book
    end

    it 'should not create a version' do
      book.versions.count.should eq(0)
    end

    it 'should set version number 1' do
      book.version_number.should eq(1)
    end
  end

  describe 'updating a versioned object' do
    it 'should create a new version if attributes were changed' do
      mock.any_instance_of(Vidibus::Versioning::Version).save { true }
      stub.any_instance_of(Vidibus::Versioning::Version).number { 1 }
      book.update_attributes(:title => 'something')
    end

    it 'should not create a version if update fails' do
      dont_allow.any_instance_of(Vidibus::Versioning::Version).save { true }
      book.update_attributes(:title => nil)
    end

    it 'should not create a version unless any of the versioned attributes were changed' do
      dont_allow.any_instance_of(Vidibus::Versioning::Version).save { true }
      book.update_attributes(:title => 'title 1')
    end

    it 'should set the previous update time as creation time of the new version' do
      past = stub_time('2011-01-01 01:00')
      book
      stub_time('2011-01-01 02:00')
      book.update_attributes(:title => 'title 2')
      book.reload.versions.count.should eq(1)
      book.versions.first.created_at.should eq(past)
    end

    it 'should apply a given update time as creation time of version' do
      future = Time.parse('2012-01-01 00:00 UTC')
      version = book.version(:next)
      version.update_attributes(:title => 'THE FUTURE!', :updated_at => future)
      book.reload
      book.versions.count.should eq(1)
      book.versions.first.created_at.should eq(future)
    end

    context 'with only one version' do
      before do
        book.update_attributes(:title => 'title 2')
      end

      it 'should create the first version object' do
        book.versions.count.should eq(1)
      end

      it 'should store the previous attributes as versioned ones' do
        expected = {'title' => 'title 1', 'text' => 'text 1'}
        book.versions.last.versioned_attributes.should eq(expected)
      end

      it 'should set 2 as version number on versioned object' do
        book.version_number.should eq(2)
      end

      it 'should set 1 as version number on version object' do
        book.versions.last.number.should eq(1)
      end
    end

    context 'with an editing time set to 300 seconds' do
      it 'should have Article.versioning_options set properly' do
        Article.versioning_options[:editing_time].should eq(300)
      end

      context 'without versions' do
        before do
          stub_time('2011-06-25 13:10')
          article
        end

        context 'before editing time has passed' do
          before do
            stub_time('2011-06-25 13:11')
            article.update_attributes(:text => 'text 3')
            article.reload
          end

          it 'should update the versioned object' do
            article.text.should eq('text 3')
          end

          it 'should not create a version object' do
            article.versions.count.should eq(0)
          end
        end
      end

      context 'and several past versions' do
        before do
          stub_time('2011-01-01 00:00')
          article
          stub_time('2011-01-01 01:00')
          article.update_attributes(:title => 'old title', :text => 'old text')
          stub_time('2011-06-25 13:10')
          article.update_attributes(:title => 'title 2', :text => 'text 2')
        end

        context 'an update' do
          context 'before editing time has passed' do
            before do
              stub_time('2011-06-25 13:11')
              article.update_attributes(:text => 'text 3')
              article.reload
            end

            it 'should update the versioned object' do
              article.text.should eq('text 3')
            end

            it 'should not create another version object' do
              article.versions.count.should eq(2)
            end
          end

          context 'after editing time has passed' do
            before do
              stub_time('2011-06-25 13:16')
              article.update_attributes(:text => 'text 3')
              article.reload
            end

            it 'should update the versioned object' do
              article.text.should eq('text 3')
            end

            it 'should create a new version object' do
              article.versions.count.should eq(3)
            end

            it 'should store the previous attributes as versioned ones' do
              article.versions.last.
                versioned_attributes['title'].should eq('title 2')
            end

            it 'should set version number 4 on versioned object' do
              article.version_number.should eq(4)
            end

            it 'should set version number 3 on version object' do
              article.versions.last.number.should eq(3)
            end
          end

          context 'after editing time has passed and unversioned attributes were changed' do
            before do
              stub_time('2011-06-25 13:16')
              article.update_attributes(:published => true)
              article.reload
              article.update_attributes(:text => 'text 3')
              article.reload
            end

            it 'should create a new version object' do
              article.versions.count.should eq(3)
            end
          end

          context 'of an immediately rolled back version' do
            before do
              article.migrate!(:previous)
              article.reload
            end

            it 'should have 3 version objects' do
              article.versions.count.should eq(3)
            end

            context 'before editing time has passed' do
              before do
                stub_time('2011-06-25 13:11')
                article.update_attributes(:text => 'text 3')
                article.reload
              end

              it 'should create another version object' do
                article.versions.count.should eq(4)
              end
            end
          end
        end
      end

      context 'and a future version' do
        before do
          stub_time('2011-06-25 13:10')
          article.update_attributes({
            :title => 'THIS IS THE FUTURE!',
            :updated_at => Time.parse('2012-01-01 00:00')
          })
          article.reload
        end

        context 'an update' do
          context 'before editing time has passed' do
            before do
              stub_time('2011-06-25 13:11')
            end

            it 'should update the versioned object' do
              article.update_attributes(:text => 'text 3')
              article.reload.text.should eq('text 3')
            end

            it 'should create a new version object' do
              article.update_attributes(:text => 'text 3')
              article.reload.versions.count.should eq(2)
            end
          end

          context 'after editing time has passed' do
            before do
              stub_time('2011-06-25 13:16')
            end

            it 'should update the versioned object' do
              article.update_attributes(:text => 'text 3')
              article.reload.text.should eq('text 3')
            end

            it 'should create a new version object' do
              article.update_attributes(:text => 'text 3')
              article.reload.versions.count.should eq(2)
            end
          end
        end
      end
    end
  end

  describe 'updating a version' do
    context 'that is previous' do
      before do
        book.update_attributes(:title => 'title 2')
      end

      it 'should apply changes to the version' do
        book.version(1).update_attributes(:title => 'new title')
        version = book.reload.version(1)
        version.title.should eq('new title')
      end

      it 'should not change the versioned object' do
        book_before = book
        book.version(1).update_attributes(:title => 'new title')
        book.reload.should eq(book_before)
      end

      it 'should return true like regular saving would' do
        book.version(1).update_attributes(:title => 'new title').should eq(true)
      end

      it 'should perform no update if validation fails' do
        book.version(1).update_attributes(:title => nil).should eq(false)
        book.reload.version(1).title.should eq('title 1')
      end
    end

    context 'that is current' do
      it 'should apply changes to the versioned object itself' do
        book.version(1).update_attributes(:title => 'new title')
        version = book.reload.version(1)
        version.title.should eq('new title')
      end

      it 'should not create an additional version' do
        book.version(1).update_attributes(:title => 'new title')
        book.versions.count.should eq(0)
      end
    end

    context 'that has been reverted' do
      before do
        book.update_attributes(:text => 'text 2')
        book.undo!
        book.redo!
      end

      it 'should apply changes to the versioned object itself' do
        book.version(2).update_attributes(:text => 'new text')
        book.reload.text.should eq('new text')
      end

      it 'should apply changes to the version object' do
        book.version(2).update_attributes(:text => 'new text')
        book.reload.versions.last.
          versioned_attributes['text'].should eq('new text')
      end
    end
  end

  it 'should allow versioning embedded documents'

  it 'should deal with related documents'
end
