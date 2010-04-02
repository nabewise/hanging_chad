class Vote < ActiveRecord::Base
  belongs_to :user
  belongs_to :voteable, :polymorphic => true

  validates_uniqueness_of :user_id, :scope => [:voteable_id, :voteable_type, :kind]

  after_save :update_total

  protected
  def update_total
    transaction do
      total = VoteTotal.
        find_or_create_by_voteable_type_and_voteable_id_and_kind(
          voteable_type, voteable_id, kind)

      total.total = voteable.votes.count(:conditions => {:kind => kind})
      total.ayes = voteable.votes.count(:conditions => {:kind => kind, :value => true})
      total.nays = voteable.votes.count(:conditions => {:kind => kind, :value => false})
      total.update_attribute(:percent_ayes, total.ayes.to_f/total.total)
    end
  end
end
