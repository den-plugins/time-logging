module ExtendAccountController

  def self.included(base)
    base.class_eval do
      before_filter :clear_cache_issues, :only => [:logout]

      def clear_cache_issues
        Rails.cache.write :project_issue_ids, nil
        Rails.cache.write :non_project_issue_ids, nil
      end
    end
  end
end
