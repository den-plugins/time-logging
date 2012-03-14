module TimeEntryExtn
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def get_hours_by_date(current_date, issue)
      arr = []
      (0..6).each do |val| 
        ret = TimeEntry.find(:all, :conditions=>["spent_on = ? AND issue_id = ?", current_date+val, issue.id])
        arr << (ret.empty? ? 0.0 : ret.first.hours)
      end
      arr
    end
  end
end

TimeEntry.send(:include,TimeEntryExtn)
