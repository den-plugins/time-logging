module TimeEntryExtn
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def get_hours_by_date(current_date, issue)
      ret = TimeEntry.find(:all, :conditions=>["spent_on = ? AND issue_id = ?", current_date, issue.id])
      ret.empty? ? 0.0 : ret.first.hours
    end
  end
end

TimeEntry.send(:include,TimeEntryExtn)
