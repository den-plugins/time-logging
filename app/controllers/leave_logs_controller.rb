class LeaveLogsController < ApplicationController

  before_filter :require_login, :except => [:save_leaves]
  skip_before_filter :check_if_login_required, :only => [:save_leaves]
  before_filter :restrict_access, :only => [:save_leaves]

  def save_leaves
    # params : username(string), date_from(date), date_to(date), half_day(boolean)
    if params[:username] && params[:date_from] && params[:date_to]
      @error = []
      @success = []
      maxed_hours = false
      user = User.find_by_login(params[:username])
      date_from = params[:date_from].to_datetime
      date_to = params[:date_to].to_datetime
      leaves = (date_from..date_to)
      number_of_hours = params[:half_day] == 1 ? 4.00 : 8.00
      maximum_hours = 8

      leaves.each do |leave|
        current_day_hours = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, leave]).sum(&:hours).to_f
        unless current_day_hours < maximum_hours
          maxed_hours = true
          @error << "Logs for #{leave.to_date} is already maxed to #{maximum_hours} hours for #{user.login}."
        end
      end

      unless maxed_hours
        members = user.members

        members.each do |member|

          leaves.each do |leave|
            allocations = member.resource_allocations
            allocations.each do |allocation|
              if allocation.start_date <= leave && allocation.end_date >= leave &&
                  allocation.resource_allocation > 0
                total_allocation = get_total_allocation(members, leave)
                if member.project.accounting_type == "Billable"

                  if total_allocation == 100 || total_allocation < 100
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
                  if total_allocation == 100 || total_allocation < 100
                    timelog(leave, number_of_hours, user, member, allocation, "admin")
                  elsif total_allocation > 100
                    tmp_total_allocation = get_total_allocation(members, leave, "Billable")
                    unless tmp_total_allocation == 100
                      timelog_over_allocation(total_allocation, leave, number_of_hours, user, member, allocation, "admin")
                    end
                  end
                end
              end
            end
          end
        end

        leaves.each do |leave|
          total_allocation = get_total_allocation(members, leave)
          if total_allocation < 100
            engineer_admin_under_allocation(total_allocation, leave, number_of_hours, user)
          end
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
    hours_spent = "%.2f" % (number_of_hours * allocation.resource_allocation/total_allocation)
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def timelog(leave, number_of_hours, user, member, allocation, type)
    project = get_project(type, member)
    issue = get_leave_issue(project)
    hours_spent = "%.2f" % (number_of_hours * allocation.resource_allocation/100)
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def engineer_admin_under_allocation(total_allocation, leave, number_of_hours, user)
    project = get_project("admin")
    issue = get_leave_issue(project)
    diff_alloc = 100 - total_allocation
    hours_spent = "%.2f" % (number_of_hours * diff_alloc/100)
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
    task_tracker = Tracker.find_by_name("Task")
    project.issues.find(:first, :conditions => ["tracker_id = ? OR tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, task_tracker.id, "%LEAVE%"])
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

  def get_total_allocation(members, leave, acctg=nil)
    sum = 0
    members.each do |member|
      sum += get_alloc(member, leave, acctg)
    end
    sum
  end

  def get_alloc(member, leave, acctg=nil)
    allocations = member.resource_allocations
    total_allocation = 0
    unless allocations.empty?
      allocations.each do |allocation|
        unless acctg
          if allocation.start_date <= leave && allocation.end_date >= leave &&
              allocation.resource_allocation > 0
            total_allocation += allocation.resource_allocation
          end
        else
          if allocation.start_date <= leave && allocation.end_date >= leave &&
              allocation.resource_allocation > 0 && allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"]
            total_allocation += allocation.resource_allocation
          end
        end
      end
    end
    total_allocation
  end


end