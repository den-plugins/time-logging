class HolidayLogsJob
  include Delayed::ScheduledJob

  run_every(Time.parse("12am") + 1.minute)

  def perform
    @holiday_job_log ||= Logger.new("#{Rails.root}/log/holiday_job.log")
    @holiday = Holiday.find(:all, :conditions => ["event_date = ?", Date.today])[0]
    if @holiday && @holiday.event_date.wday != 6 && @holiday.event_date.wday != 7
      users = User.active
      users.each do |user|
        @user = user
        members = @user.members
        total_allocation = 0
        support_tracker = Tracker.find_by_name("Support")
        get_location
        members.each do |member|

          project_parent = member.project.parent
          @project = project_parent ? project_parent.children.select { |v| v.identifier.to_s.downcase[/admin|na/] }[0] || member.project : member.project
          @issue = @project.issues.find(:first, :conditions => ["tracker_id = ? AND subject LIKE ?", support_tracker.id, "%oliday%"])
          allocations = member.resource_allocations
          holiday_location = Holiday::LOCATIONS[@holiday.location]

          allocations.each do |alloc|
            if alloc.start_date <= @holiday.event_date && alloc.end_date >= @holiday.event_date &&
                alloc.resource_allocation > 0 && holiday_location.downcase.include?(@locations[alloc.location].downcase)

              @hours_spent = 8 * alloc.resource_allocation/100
              total_allocation =+alloc.resource_allocation
              save_time_entry
            end
          end
        end
        if total_allocation < 100
          @issue = Project.find_by_identifier("existengradmn").issues.find(:first, :conditions => ["tracker_id = ? AND subject LIKE ?", support_tracker.id, "%oliday%"])
          diff_alloc = 100 - total_allocation
          @hours_spent = 8 * diff_alloc/100
          save_time_entry
        end

      end
    end
  end


  def get_location
    @locations = {}
    User::LOCATIONS.each do |location|
      hlocation = Holiday::LOCATIONS.detect { |k, v| v.downcase.eql?(location.downcase) }
      @locations[hlocation[0]] = hlocation[1] if hlocation
    end
  end


  def save_time_entry
    if @issue && @project && @user
      new_time = TimeEntry.new(:project => @project, :issue => @issue, :user => @user,
                               :spent_on => @holiday.event_date, :activity_id => 9, :hours => @hours_spent)
      new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
      if new_time.save
        @holiday_job_log.info("Added #{@hours_spent} hours on #{@holiday.event_date.to_s} to #{@issue.subject} of project #{@project} for #{@user.login}")
      else
        @holiday_job_log.info("Failed to add #{@hours_spent} hours on #{@holiday.event_date.to_s} to #{@issue.subject} of project #{@project} for #{@user.login}")
      end
    end
  end
end