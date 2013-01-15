class HolidayLogsJob
  include Delayed::ScheduledJob

  run_every(Time.parse("12am") + 1.minute)

  def perform
    @holiday_job_log ||= Logger.new("#{Rails.root}/log/holiday_job.log")
    @holiday = Holiday.find(:all, :conditions => ["event_date = ?", Date.today])[0]
    if @holiday && @holiday.event_date.wday != 6 && @holiday.event_date.wday != 0
      users = User.all(:conditions => "status = #{User::STATUS_ACTIVE} and is_engineering = #{true} or skill = 'Sys Ad'")
      get_location

      users.each do |user|
        current_day_hours = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, @holiday.event_date]).sum(&:hours).to_f
        @assigned_to_billable = false
        if current_day_hours == 0.0
          @number_of_hours = 8.0
          @total_allocation = 0.0
          holiday_location = Holiday::LOCATIONS[@holiday.location]

          members = user.members.reject { |v| v.project.project_type != "Development" }

          members.each do |member|

            allocations = member.resource_allocations

            allocations.each do |allocation|
              if allocation.start_date <= @holiday.event_date && allocation.end_date >= @holiday.event_date &&
                  allocation.resource_allocation > 0 &&
                  holiday_location.downcase.include?(@locations[allocation.location].downcase)
                @total_allocation = get_total_allocation(members, "Billable")

                if member.project.accounting_type == "Billable"

                  if @total_allocation == 100 || @total_allocation < 100
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      timelog(user, member, allocation)
                      @assigned_to_billable = true
                    end

                  elsif @total_allocation > 100
                    total_billable_allocation = get_total_allocation(members, "Both")
                    total_shadow_allocation = get_total_allocation(members, "Project Shadow")
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      if total_billable_allocation >= 100 && total_shadow_allocation > 0
                        timelog(user, member, allocation)
                        @assigned_to_billable = true
                      else
                        timelog_over_allocation(user, member, allocation)
                      end
                    end
                  end
                end
              end
            end
          end
          @total_spent_time = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, @holiday.event_date]).sum(&:hours).to_f
          if (@assigned_to_billable && @total_spent_time < @number_of_hours) ||
              (holiday_location.downcase.include?(user.location.downcase) && @total_spent_time < @number_of_hours)
            engineer_admin_under_allocation(user)
          end
        end
      end
    end
  end


  private

  def timelog_over_allocation(user, member, allocation)
    project = get_project(member)
    issue = get_holiday_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours * allocation.resource_allocation/@total_allocation).to_f
    save_time_entry(issue, project, user, hours_spent)
  end

  def timelog(user, member, allocation)
    project = get_project(member)
    issue = get_holiday_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours * allocation.resource_allocation/100).to_f
    save_time_entry(issue, project, user, hours_spent)
  end

  def engineer_admin_under_allocation(user)
    project = get_project()
    issue = get_holiday_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours - @total_spent_time).to_f
    save_time_entry(issue, project, user, hours_spent)
  end

  def get_location
    @locations = {}
    User::LOCATIONS.each do |location|
      hlocation = Holiday::LOCATIONS.detect { |k, v| v.downcase.eql?(location.downcase) }
      @locations[hlocation[0]] = hlocation[1] if hlocation
    end
  end

  def get_project(member=nil)
    unless member && member.project.accounting_type == "Billable"
      Project.find_by_identifier("existengradmn")
    else
      project_parent = member.project.parent
      project_parent ? project_parent.children.select { |v| v.identifier.to_s.downcase[/admin|na/] }[0] || member.project : member.project
    end
  end

  def get_holiday_issue(project, user)
    support_tracker = Tracker.find_by_name("Support")
    task_tracker = Tracker.find_by_name("Task")
    issue = project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ? OR tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%HOLIDAY%", task_tracker.id, "%HOLIDAY%"])
    if issue.nil?
      issue = Issue.new
      issue.attributes = {"start_date" => "2012-01-01", "description" => "",
                          "estimated_hours" => "", "subject" => "Holidays", "priority_id" => "4",
                          "remaining_effort" => "", "done_ratio" => "0", "due_date" => "",
                          "acctg_type" => "10", "fixed_version_id" => "", "status_id" => "2",
                          "custom_field_values" => {"34" => "0"}, "assigned_to_id" => "#{user.id}",
                          "tracker_id" => "3", "project_id" => "#{project.id}", "author_id" => "#{user.id}"}
    end
    issue
  end


  def save_time_entry(issue, project, user, hours_spent)
    if issue && project && user
      new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                               :spent_on => @holiday.event_date, :activity_id => 9, :hours => hours_spent)
      new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
      if new_time.save
        @holiday_job_log.info("Added #{hours_spent} hours on #{@holiday.event_date.to_s} to #{issue.subject} of project #{project} for #{user.login}")
      else
        @holiday_job_log.info("Failed to add #{hours_spent} hours on #{@holiday.event_date.to_s} to #{issue.subject} of project #{project} for #{user.login} : #{new_time.errors.full_messages}")
      end
    end
  end

  def get_total_allocation(members, acctg=nil)
    sum = 0
    members.each do |member|
      sum += get_alloc(member, acctg)
    end
    sum
  end

  def get_alloc(member, acctg=nil)
    allocations = member.resource_allocations
    allocation_total = 0
    holiday_location = Holiday::LOCATIONS[@holiday.location]
    get_location
    unless allocations.empty?
      allocations.each do |allocation|
        if allocation.start_date <= @holiday.event_date && allocation.end_date >= @holiday.event_date &&
            allocation.resource_allocation > 0
          case acctg
            when "Billable"
              allocation_total += allocation.resource_allocation if allocation.resource_type == (Hash[ResourceAllocation::TYPES]["Billable"] ||
                  allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"] ||
                  allocation.resource_type == Hash[ResourceAllocation::TYPES]["Project Shadow"]) &&
                  member.project.acctg_type == Enumeration.find_by_name("Billable").id
            when "Both"
              allocation_total += allocation.resource_allocation if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] ||
                  allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"] &&
                      member.project.acctg_type == Enumeration.find_by_name("Billable").id
            when "Project Shadow"
              allocation_total += allocation.resource_allocation if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Project Shadow"]
            else
              allocation_total += allocation.resource_allocation
          end
        end
      end
    end
    allocation_total
  end

end