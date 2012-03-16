module TimeEntryExtn
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def get_hours_by_date(current_date, issue)
      arr = []
      dates = [*current_date.beginning_of_week..(current_date.end_of_week - 1.day)].push(current_date.beginning_of_week - 1)
      dates.each do |date|
        ret = TimeEntry.first(:conditions=>["spent_on = ? AND issue_id = ?", date, issue.id])
        arr << (ret.nil? ? 0.0 : ret.hours)
      end
      arr
    end

    def get_total(week_start, issue)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND issue_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, issue.id, week_start - 1.day, week_start + 6.days]).to_f
    end

    def weekly_total(week_start)
      TimeEntry.sum(:hours, :conditions=>["user_id = ? AND spent_on BETWEEN ? AND ?", User.current.id, week_start - 1.day, week_start + 6.days]).to_f
    end
  end
end

TimeEntry.send(:include,TimeEntryExtn)