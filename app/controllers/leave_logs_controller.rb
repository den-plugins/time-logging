class LeaveLogsController < ApplicationController

  before_filter :require_login, :except => [:save_leaves]
  skip_before_filter :check_if_login_required, :only => [:save_leaves]
  before_filter :restrict_access, :only => [:save_leaves]

  def save_leaves
    # params : username(string), date_from(date), date_to(date), half_day(boolean)
    if params[:username] && params[:date_from] && params[:date_to]
      @error = []
      user = User.find_by_login(params[:username])
      date_from = params[:date_from].to_datetime
      date_to = params[:date_to].to_datetime
      leaves = (date_from..date_to)
      number_of_hours = params[:half_day] == 1 ? 4 : 8

      members = user.members.select { |v| !v.resource_allocations.empty? && v.resource_allocations[0].start_date < date_to &&
          v.resource_allocations[0].end_date > date_from &&
          v.resource_allocations[0].resource_allocation > 0 }

      total_allocation = members.sum { |x| x.resource_allocations[0].resource_allocation }

      members.each do |member|

        allocation = member.resource_allocations[0]

        leaves.each do |leave|
          if member.project.accounting_type == "Billable"

            if total_allocation == 100
              if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                timelog(leave, number_of_hours, user, member, allocation, "project")
              else
                timelog(leave, number_of_hours, user, member, allocation, "admin")
              end

            elsif total_allocation > 100
              if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                timelog_over_allocation(total_allocation, leave, number_of_hours, user, member, allocation, "project")
              else
                timelog_over_allocation(total_allocation, leave, number_of_hours, user, member, allocation, "admin")
              end
            end
          else
            if total_allocation == 100
              timelog(leave, number_of_hours, user, member, allocation, "admin")
            elsif total_allocation > 100
              tmp_members = user.members.select { |v| !v.resource_allocations.empty? && v.resource_allocations[0].start_date < date_to &&
                  v.resource_allocations[0].end_date > date_from &&
                  v.resource_allocations[0].resource_allocation > 0 &&
                  v.resource_allocations[0].resource_type == Hash[ResourceAllocation::TYPES]["Billable"] }
              tmp_total_allocation = tmp_members.sum { |x| x.resource_allocations[0].resource_allocation }
              if tmp_total_allocation > 100
                timelog_over_allocation(total_allocation, leave, number_of_hours, user, member, allocation, "admin")
              end
            end
          end
        end
      end

      leaves.each do |leave|
        if total_allocation < 100
          engineer_admin_under_allocation(total_allocation, leave, number_of_hours, user)
        end
      end
      render :json => {:success => @error.empty?, :error => @error}.to_json
    else
      render :json => {:success => false}.to_json
    end

  end

  private

  def timelog_over_allocation(total_allocation, leave, number_of_hours, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_leave_issue(project)
    hours_spent = number_of_hours * allocation.resource_allocation/total_allocation
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def timelog(leave, number_of_hours, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_leave_issue(project)
    hours_spent = number_of_hours * allocation.resource_allocation/100
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def engineer_admin_under_allocation(total_allocation, leave, number_of_hours, user)
    project = get_project("admin")
    issue = get_leave_issue(project)
    diff_alloc = 100 - total_allocation
    hours_spent = number_of_hours * diff_alloc/100
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def get_project(type, member=nil)
    unless type == "project"
      Project.find_by_identifier("existengradmn")
    else
      project_parent = member.project.parent
      project_parent ? project_parent.children.select { |v| v.identifier.to_s.downcase[/admin|na/] }[0] || member.project : member.project
    end
  end

  def get_leave_issue(project)
    support_tracker = Tracker.find_by_name("Support")
    project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%LEAVE%"])
  end

  def save_time_entry(leave, issue, project, user, hours_spent)
    if issue && project && user
      new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                               :spent_on => leave, :activity_id => 9, :hours => hours_spent)
      new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
      @error << "#{project}:#{new_time.errors.full_messages}" unless new_time.save
    end
  end

  def restrict_access
    head :unauthorized unless params[:access_token].eql? AUTH_TOKEN
  end

end