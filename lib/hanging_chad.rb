module HangingChad
  class NoKindSpecified < RuntimeError; end
  class KindDoesNotExist < RuntimeError; end

  module ClassMethods
    def hanging_chad
      read_inheritable_attribute(:hanging_chad) ||
        write_inheritable_attribute(:hanging_chad, nil)
    end

    def hanging_chad=(val)
      write_inheritable_attribute(:hanging_chad, val)
    end

    def has_votes(options={})
      unless hanging_chad
        self.hanging_chad = {:kinds => []}
        has_many :votes, :as => :voteable, :dependent => :destroy
        has_one :vote_total, :as => :voteable, :dependent => :destroy
        has_many :vote_totals, :as => :voteable, :dependent => :destroy

        named_scope(:sort_by_votes, lambda do |kind|
          quoted_kind = ActiveRecord::Base.connection.quote(kind.to_s)
          {:joins => "LEFT OUTER JOIN vote_totals ON vote_totals.voteable_type = '#{self}' AND vote_totals.voteable_id = #{table_name}.id AND vote_totals.kind = #{quoted_kind}",
            :order => "percent_ayes DESC"}
        end)

        named_scope(:include_votes_by_user, lambda do |user|
          if user
            if hanging_chad[:kinds].empty?
              { :select => "#{table_name}.*, votes.value AS user_#{user.id}_vote", 
                :joins => "LEFT OUTER JOIN votes ON votes.voteable_type = '#{self}' AND votes.voteable_id = #{table_name}.id AND votes.user_id = #{user.id.to_i}" }
            else
              joins = hanging_chad[:kinds].map do |kind|
                votes = "#{kind}_votes"
                ["#{votes}.value AS user_#{user.id.to_s}_#{kind}_vote",
                 "LEFT OUTER JOIN votes AS #{votes} ON #{votes}.voteable_type = '#{self}' AND #{votes}.voteable_id = #{table_name}.id AND #{votes}.user_id = #{user.id.to_i} AND #{votes}.kind = '#{kind}'"]
              end
              
              { :select => "#{table_name}.*, #{joins.map(&:first).join(",")}",
                :joins => joins.map(&:last).join(" ") }
            end
          else
            {}
          end
        end)
      end
      
      if options[:kind]
        kind_name = options[:kind].to_sym
        hanging_chad[:kinds] << kind_name

        has_many "#{kind_name}_votes", 
                 :class_name => 'Vote',
                 :as => :voteable,
                 :conditions => {:kind => kind_name.to_s}
        has_one "#{kind_name}_vote_total",
                :class_name => 'Vote',
                :as => :voteable,
                :conditions => {:kind => kind_name.to_s}
      end
      include HangingChad::InstanceMethods
    end

    def has_votes_for(kind, options={})
      has_votes(options.merge(:kind => kind))
    end
  end

  module InstanceMethods
    def hanging_chad
      self.class.hanging_chad
    end

    def record_vote(user, value, kind=nil)
      check_kind(kind)

      vote = votes.find_or_create_by_user_id_and_kind(user.id, kind.to_s)
      vote.update_attribute(:value, value)
    end

    def vote_from_user(user, kind=nil)
      return nil unless user
      check_kind(kind)
      @vote_from_user ||= {}
      unless @vote_from_user[[user.id,kind]]
        if (vote = read_included_vote_attribute(user, kind)) != nil
          @vote_from_user[[user.id,kind]] = (vote == :no_vote)? nil : vote
        else
          @vote_from_user[[user.id,kind]] =
            votes.find(:first, 
                       :conditions => {:kind => kind.to_s, :user_id => user.id}).try(:value)
        end
      end
      @vote_from_user[[user.id,kind]]
    end

    def user_voted?(user, kind=nil)
      [true, false].include?(vote_from_user(user, kind))
    end


    def aye_votes(kind=nil)
      get_vote_total(:ayes, kind)
    end

    def nay_votes(kind=nil)
      get_vote_total(:nays, kind)
    end

    def total_votes(kind=nil)
      get_vote_total(:total, kind)
    end

    def percent_aye_votes(kind=nil)
      get_vote_total(:percent_ayes, kind)
    end

    def percent_nay_votes(kind=nil)
      1.0 - percent_aye_votes(kind)
    end

    protected
    def get_vote_total(field, kind=nil)
      check_kind(kind)
      vote_totals.find(:first, :conditions => {:kind => kind.to_s}).try(field)
    end

    def read_included_vote_attribute(user, kind=nil)
      attr_name = (kind)? "user_#{user.id}_#{kind}_vote" : "user_#{user.id}_vote"
      
      if has_attribute?(attr_name)
        v = read_attribute(attr_name)
        case v
        when "1", "t"
          true
        when "0", "f"
          false
        else
          :no_vote
        end
      else
        nil
      end
    end

    def check_kind(kind)
      raise HangingChad::NoKindSpecified if !kind && !hanging_chad[:kinds].empty?
      raise HangingChad::KindDoesNotExist if kind && !hanging_chad[:kinds].include?(kind.to_sym)
    end
  end
end

