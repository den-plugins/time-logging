class HolidayLogsJob
  include Delayed::ScheduledJob

  run_every(Time.parse("12am") + 1.minute)

  def perform
    holiday_job_log ||= Logger.new("#{Rails.root}/log/holiday_job.log")
    holiday = Holiday.find(:all, :conditions => ["event_date = ?", Date.today])[0]
    if holiday && holiday.event_date.wday != 6 && holiday.event_date.wday != 0
      users = User.all(:conditions => "status = #{User::STATUS_ACTIVE} and is_engineering = #{true} or skill = 'Sys Ad'")
      get_location

      users.each do |user|
        current_day_hours = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, holiday.event_date]).sum(&:hours).to_f
        if current_day_hours == 0.0

          total_allocation = 0
          holiday_location = Holiday::LOCATIONS[holiday.location]

          members = user.members

          members.each do |member|

            allocations = member.resource_allocations

            allocations.each do |allocation|
              if allocation.start_date <= holiday.event_date && allocation.end_date >= holiday.event_date &&
                  allocation.resource_allocation > 0 &&
                  holiday_location.downcase.include?(@locations[allocation.location].downcase)
                total_allocation = get_total_allocation(members, holiday)

                if member.project.accounting_type == "Billable"

                  if total_allocation == 100 || total_allocation < 100
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      timelog(holiday, holiday_job_log, user, member, allocation, "project")
                    else
                      timelog(holiday, holiday_job_log, user, member, allocation, "admin")
                    end

                  elsif total_allocation > 100
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, "project")
                    else
                      timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, "admin")
                    end
                  end
                else
                  if total_allocation == 100 || total_allocation < 100
                    timelog(holiday, holiday_job_log, user, member, allocation, "admin")
                  elsif total_allocation > 100
                    tmp_total_allocation = get_total_allocation(members, holiday, "Billable")
                    unless tmp_total_allocation == 100
                      timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, "admin")
                    end
                  end
                end
              end
            end
          end

          if total_allocation < 100
            engineer_admin_under_allocation(total_allocation, holiday, holiday_job_log, user)
          end
        end
      end
    end
  end


  private

  def timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_holiday_issue(project)
    hours_spent = "%.2f" % (8 * allocation.resource_allocation/total_allocation).to_f
    save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
  end

  def timelog(holiday, holiday_job_log, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_holiday_issue(project)
    hours_spent = "%.2f" % (8 * allocation.resource_allocation/100).to_f
    save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
  end

  def engineer_admin_under_allocation(total_allocation, holiday, holiday_job_log, user)
    project = get_project("admin")
    issue = get_holiday_issue(project)
    diff_alloc = 100 - total_allocation
    hours_spent = "%.2f" % (8 * diff_alloc/100).to_f
    save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
  end

  def get_location
    @locations = {}
    User::LOCATIONS.each do |location|
      hlocation = Holiday::LOCATIONS.detect { |k, v| v.downcase.eql?(location.downcase) }
      @locations[hlocation[0]] = hlocation[1] if hlocation
    end
  end

  def get_project(type, member=nil)
    unless type == "project"
      Project.find_by_identifier("existengradmn")
    else
      project_parent = member.project.parent
      project_parent ? project_parent.children.select { |v| v.identifier.to_s.downcase[/admin|na/] }[0] || member.project : member.project
    end
  end

  def get_holiday_issue(project)
    support_tracker = Tracker.find_by_name("Support")
    project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%HOLIDAY%"])
  end


  def save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
    if issue && project && user
      new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                               :spent_on => holiday.event_date, :activity_id => 9, :hours => hours_spent)
      new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
      if new_time.save
        holiday_job_log.info("Added #{hours_spent} hours on #{holiday.event_date.to_s} to #{issue.subject} of project #{project} for #{user.login}")
      else
        holiday_job_log.info("Failed to add #{hours_spent} hours on #{holiday.event_date.to_s} to #{issue.subject} of project #{project} for #{user.login} : #{new_time.errors.full_messages}")
      end
    end
  end

  def get_total_allocation(members, holiday, acctg=nil)
    sum = 0
    members.each do |member|
      sum += get_alloc(member, holiday, acctg)
    end
    sum
  end

  def get_alloc(member, holiday, acctg=nil)
    allocations = member.resource_allocations
    total_allocation = 0
    holiday_location = Holiday::LOCATIONS[holiday.location]
    get_location
    unless allocations.empty?
      allocations.each do |allocation|
        unless acctg
          if allocation.start_date <= holiday.event_date && allocation.end_date >= holiday.event_date &&
              allocation.resource_allocation > 0 &&
              holiday_location.downcase.include?(@locations[allocation.location].downcase)
            total_allocation += allocation.resource_allocation
          end
        else
          if allocation.start_date <= holiday.event_date && allocation.end_date >= holiday.event_date &&
              allocation.resource_allocation > 0 && allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"]
            total_allocation += allocation.resource_allocation
          end
        end
      end
    end
    total_allocation
  end

end