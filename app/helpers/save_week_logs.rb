module SaveWeekLogs
  
  def self.save(hash, user)
    hash.each_key do |issue|
      hash[issue].each_key do |date|
        time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", user.id, issue, Date.parse(date)])
        if time_entry.empty?
          if(hash[issue][date]['hours'].match(/\d+/))
            proj_i = Issue.find(issue)
            new_time = TimeEntry.new(:project => proj_i.project, :issue => proj_i, :user => User.current)
            new_time.hours = Float hash[issue][date]['hours']
            new_time.spent_on = Date.parse(date)
            new_time.activity_id = 9
            new_time.save!
          end
        else
          time_entry.first.hours = Float hash[issue][date]['hours'] rescue time_entry.first.hours = 0
          time_entry.first.save!
        end
      end      
    end
  end
  
end
