module TimeEntryExtn
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def get_hours_by_date(current_date, issue)
      current_date = current_date - 1
      arr = []
      (0..6).each do |val| 
        ret = TimeEntry.find(:all, :conditions=>["spent_on = ? AND issue_id = ?", current_date+val, issue.id])
        arr << (ret.empty? ? 0.0 : ret.first.hours)
        puts (current_date+val)
        puts arr[val]
      end
      sun = arr[0]
      arr.delete_at 0
      arr << sun
      arr
    end

    def get_total(week_start, issue)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND issue_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, issue.id, week_start, week_start + 7.day]).to_f
    end

    def weekly_total(week_start)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, week_start, week_start + 7.day]).to_f
    end
  end
end

TimeEntry.send(:include,TimeEntryExtn)
