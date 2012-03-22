module ExtendAccountController

  def self.included(base)
    base.class_eval do
      before_filter :clear_session_issues, :only => [:logout]

      def clear_session_issues
        session[:project_issue_ids] = nil
        session[:non_project_issue_ids] = nil
      end
    end
  end
end
