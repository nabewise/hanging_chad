require 'test_helper'
require 'active_record'

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

template_path = File.join(File.dirname(__FILE__), '..', 'generators', 'hanging_chad', 'templates')
require File.join(template_path, 'create_hanging_chad_tables')
require File.join(template_path, 'vote')
require File.join(template_path, 'vote_total')
require "#{File.dirname(__FILE__)}/../init"

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :reviews do |t|
      t.string "name"
    end
    create_table :comments do |t|
      t.string "name"
    end
    create_table :users do |t|
      t.string "name"
    end
  end
  CreateHangingChadTables.up
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Review < ActiveRecord::Base
  has_votes
end

class Comment < ActiveRecord::Base
  has_votes_for :insightfulness
  has_votes_for :controversy
end

class User < ActiveRecord::Base
end

class HangingChadTest < ActiveSupport::TestCase
  def setup
    setup_db
    @user = User.create(:name => "Pelvis Thrustello")
  end
  def teardown
    teardown_db
  end

  context "A Review (using has_votes)" do
    should "have a hanging chad with no kinds" do
      assert_equal [], Review.hanging_chad[:kinds]
    end

    setup do
      @review = Review.create(:name => "Harumph")
    end

    context "on record vote" do
      should "fail if kind is specified" do
        assert_raise HangingChad::KindDoesNotExist do
          @review.record_vote(@user, true, :frattiness)
        end
      end

      context "with an aye vote" do
        setup do
          @review.record_vote(@user, true)
          @other_user = User.create(:name => "Eugene")
        end
        
        should("have one aye vote"){ assert_equal 1, @review.aye_votes }
        should("have no nay votes"){ assert_equal 0, @review.nay_votes }
        should("have one total vote"){ assert_equal 1, @review.total_votes }
        should("have 100% aye votes"){ assert_equal 1.0, @review.percent_aye_votes }
        should("have 0% nay votes"){ assert_equal 0.0, @review.percent_nay_votes }
        should("say that the voter voted"){ assert @review.user_voted?(@user) }
        should "say that the voter voted aye" do 
          assert_equal true, @review.vote_from_user(@user)
        end
        should "not let the voter vote again" do
          @review.record_vote(@user, true)
          assert_equal 1, @review.total_votes
        end
        should "let the voter change votes" do
          @review.record_vote(@user, false)
          assert_equal 1, @review.total_votes
          assert_equal false, @review.vote_from_user(@user)
        end
        should "not say that some other user voted" do
          assert !@review.user_voted?(@other_user)
        end

        context "returned with the voter's vote included" do
          setup do
            @voter_review = Review.include_votes_by_user(@user).first
            @other_user_review = Review.include_votes_by_user(@other_user).first
            Vote.expects(:find).never
          end

          should("say the voter voted") { assert @voter_review.user_voted?(@user) }
          should("say that some other user didn't vote") do 
            assert !@other_user_review.user_voted?(@other_user)
          end
        end

        context "followed by a nay vote" do
          setup do
            @review.record_vote(@other_user, false)
          end

          should("have two total votes"){ assert_equal 2, @review.total_votes }
          should("have 1 aye vote"){ assert_equal 1, @review.aye_votes }
          should("have 1 nay vote"){ assert_equal 1, @review.nay_votes }
          should("have 50% aye votes"){ assert_equal 0.5, @review.percent_aye_votes }
          should("have 50% nay votes"){ assert_equal 0.5, @review.percent_nay_votes }
        end
      end
    end
  end

  context "Comment (with insightfulness and controversy)" do
    should "have two kinds" do
      assert_same_elements [:insightfulness, :controversy], Comment.hanging_chad[:kinds]
    end

    setup do
      @comment = Comment.create(:name => "Hoorah")
    end

    context "on record vote" do
      should "fail if no kind is specified" do
        assert_raise HangingChad::NoKindSpecified do
          @comment.record_vote(@user, true)
        end
      end

      context "with aye votes on both kinds" do
        setup do
          @comment.record_vote(@user, true, :insightfulness)
          @comment.record_vote(@user, true, :controversy)
        end

        should "have two votes for the user/comment" do
          assert_equal 2, Vote.count(:conditions => 
                                     { :user_id => @user.id, 
                                       :voteable_type => "Comment",
                                       :voteable_id => @comment.id })
        end
        should "have one vote for each" do
          assert_equal 1, @comment.total_votes(:insightfulness)
          assert_equal 1, @comment.total_votes(:controversy)
        end

        context "returned with the voter's vote included" do
          setup do
            @voter_comment = Comment.include_votes_by_user(@user).first
            @other_user_comment = Comment.include_votes_by_user(@other_user).first
            Vote.expects(:find).never
          end
  
          should("say the voter voted") { assert @voter_comment.user_voted?(@user, :insightfulness) }
          should("say that some other user didn't vote") do 
            assert !@other_user_comment.user_voted?(@other_user, :insightfulness)
          end
        end
      end
    end
  end
end
