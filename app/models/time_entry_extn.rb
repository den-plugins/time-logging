module TimeEntryExtn
  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_session_params
   if User.current == assigned_to
     if project.project_type.to_s !~ /admin/i && project.name !~ /admin/i
       session[:project_issue_ids].push(id).uniq!
     else
       session[:non_project_issue_ids].push(id).uniq!
     end
   end
  end

  module ClassMethods
    def get_hours_by_date(current_date, issue=nil)
      arr = []
      (current_date.beginning_of_week..current_date.end_of_week).each do |date|
        ret = if issue
                TimeEntry.sum(:hours, :conditions=>["user_id=? AND spent_on = ? AND issue_id = ?", User.current.id, date, issue.id])
              else
                TimeEntry.sum(:hours, :conditions=>["user_id=? AND spent_on = ?", User.current.id, date])
              end
        arr << ret.to_f
      end
      arr
    end

    def get_total(week_start, issue)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND issue_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, issue.id, week_start.beginning_of_week, week_start.end_of_week]).to_f
    end

    def weekly_total(week_start)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, week_start.beginning_of_week, week_start.end_of_week]).to_f
    end
  end
end
