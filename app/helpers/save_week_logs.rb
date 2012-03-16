module SaveWeekLogs

  def self.save(hash, user)
    hash.each_key do |issue|
      hash[issue].each_key do |date|
        time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", user.id, issue, Date.parse(date)])
        hours = hash[issue][date]['hours'].to_hours
        total_time_entry = TimeEntry.sum(:hours, :conditions => ["user_id=? AND spent_on=?", user.id, Date.parse(date)])
        total_time_entry += hours
        if time_entry.empty?
          if(hours > 0)
            proj_i = Issue.find(issue)
            new_time = TimeEntry.new(:project => proj_i.project, :issue => proj_i, :user => User.current)
            new_time.hours = hours
            new_time.spent_on = Date.parse(date)
            new_time.activity_id = 9
            new_time.save!
          end
        else
          if(hours > 0)
            time_entry.first.hours = hours
            time_entry.first.save!
          else
            time_entry.first.destroy
          end
        end
      end
    end
  end

end
