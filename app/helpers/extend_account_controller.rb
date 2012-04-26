module ExtendAccountController

  def self.included(base)
    base.class_eval do
      before_filter :clear_cache_issues, :only => [:logout]

      def clear_cache_issues
        red = Redis.new
        red.del "project_issue_ids_#{User.current.id}"
        red.del "non_project_issue_ids_#{User.current.id}"
      end
    end
  end
end
