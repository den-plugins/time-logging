class HolidayLogsJob
  include Delayed::ScheduledJob

  run_every(Time.parse("12am") + 1.minute)

  def perform
    holiday_job_log ||= Logger.new("#{Rails.root}/log/holiday_job.log")
    holiday = Holiday.find(:all, :conditions => ["event_date = ?", Date.today])[0]
    if holiday && holiday.event_date.wday != 6 && holiday.event_date.wday != 7
      users = User.active.engineers
      get_location

      users.each do |user|

        holiday_location = Holiday::LOCATIONS[holiday.location]

        members = user.members.select { |v| !v.resource_allocations.empty? && v.resource_allocations[0].start_date < holiday.event_date &&
            v.resource_allocations[0].end_date > holiday.event_date &&
            v.resource_allocations[0].resource_allocation > 0 &&
            holiday_location.downcase.include?(@locations[v.resource_allocations[0].location].downcase) }

        total_allocation = members.sum { |x| x.resource_allocations[0].resource_allocation }

        members.each do |member|

          allocation = member.resource_allocations[0]

          if member.project.accounting_type == "Billable"

            if total_allocation == 100
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
            if total_allocation == 100
              timelog(holiday, holiday_job_log, user, member, allocation, "admin")
            elsif total_allocation > 100
              tmp_members = user.members.select { |v| !v.resource_allocations.empty? && v.resource_allocations[0].start_date < holiday.event_date &&
                  v.resource_allocations[0].end_date > holiday.event_date &&
                  v.resource_allocations[0].resource_allocation > 0 &&
                  holiday_location.downcase.include?(@locations[v.resource_allocations[0].location].downcase) &&
                  v.resource_allocations[0].resource_type == Hash[ResourceAllocation::TYPES]["Billable"] }
              tmp_total_allocation = tmp_members.sum { |x| x.resource_allocations[0].resource_allocation }
              if tmp_total_allocation > 100
                timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, "admin")
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


  private

  def timelog_over_allocation(total_allocation, holiday, holiday_job_log, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_holiday_issue(project)
    hours_spent = 8 * allocation.resource_allocation/total_allocation
    save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
  end

  def timelog(holiday, holiday_job_log, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_holiday_issue(project)
    hours_spent = 8 * allocation.resource_allocation/100
    save_time_entry(holiday, issue, project, user, hours_spent, holiday_job_log)
  end

  def engineer_admin_under_allocation(total_allocation, holiday, holiday_job_log, user)
    project = get_project("admin")
    issue = get_holiday_issue(project)
    diff_alloc = 100 - total_allocation
    hours_spent = 8 * diff_alloc/100
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
end