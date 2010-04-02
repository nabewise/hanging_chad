class VoteTotal < ActiveRecord::Base
  belongs_to :voteable, :polymorphic => true
  validates_uniqueness_of :kind, :scope => [:voteable_id, :voteable_type]
end
