module ExtendAccountController

  def self.included(base)
    base.class_eval do
      before_filter :clear_cache_issues, :only => [:logout]

      def clear_cache_issues
        Rails.cache.delete "project_issue_ids_#{User.current.id}"
        Rails.cache.delete "non_project_issue_ids_#{User.current.id}"
      end
    end
  end
end
