module FilterableMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def find_filtered(options = {})
      filters = options.delete(:tag_filters)
      mfilters = filters && filters["managed"] ? filters["managed"] : []
      bfilters = filters && filters["belongsto"] ? filters["belongsto"] : []
      options[:include] = get_include_for_find(options[:include]) unless options.delete(:eager_loading) == false
      if mfilters.blank?
        # do normal find if no filters
        result = where(options[:conditions])
                 .order(options[:order])
                 .joins(options[:join] || options[:joins])
                 .includes(options[:include])
                 .select(options[:select])
        total_count = result.length
      else
        # get count of results unfiltered
        total_count = options[:conditions] ? count(options[:conditions]) : count

        # do tag find
        # self.find_tagged_with(options.merge(:all => filters, :ns => "*"))
        result = find_tags_by_grouping(mfilters, options.merge(:ns => "*"))
      end

      result = MiqFilter.apply_belongsto_filters(result, bfilters)

      if options[:limit]
        options[:offset] ||= 0
        result = result[options[:offset]..options[:offset] + options[:limit] - 1]
      end

      return result, total_count
    end
  end

  def find_filtered_children(table)
    MiqFilter.find_children_of(self, table)
  end

  def authorized_for_user?(userid)
    user     = User.find_by_userid(userid)
    mfilters = user ? user.get_managed_filters : []
    bfilters = user ? user.get_belongsto_filters : []
    db       = self.class
    result   = true

    if db.respond_to?(:find_filtered) && !mfilters.empty?
      recs = db.where(:id => id).find_tags_by_grouping(mfilters, :ns => "*").first
      # result = false if recs.nil?
      return false if recs.nil?
    end

    if db.respond_to?(:find_filtered)
      result = false unless MiqFilter.apply_belongsto_filters([self], bfilters) == [self]
    end

    result
  end
end
