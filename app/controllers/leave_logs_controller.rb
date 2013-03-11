class LeaveLogsController < ApplicationController

  before_filter :require_login, :except => [:save_leaves]
  skip_before_filter :check_if_login_required, :only => [:save_leaves]
  before_filter :restrict_access, :only => [:save_leaves]

  def save_leaves
    # params : username(string), date_from(date), date_to(date), half_day(boolean), leave_details(string), leave_type(string)
    if params[:username] && params[:date_from] && params[:date_to]
      @error = []
      @success = []
      @comment = params[:leave_type] && params[:leave_details] ? "EGEMS: #{params[:leave_type]} -- #{params[:leave_details]}" : "EGEMS: No leave type and details."
      maxed_hours = false
      user = User.find_by_login(params[:username])
      date_from = params[:date_from].to_datetime
      date_to = params[:date_to].to_datetime
      leaves = (date_from..date_to)
      @number_of_hours = params[:half_day].to_i == 1 ? 4.00 : 8.00
      maximum_hours = 8

      leaves.each do |leave|
        current_day_hours = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, leave]).sum(&:hours).to_f
        unless current_day_hours < maximum_hours
          maxed_hours = true
          @error << "Logs for #{leave.to_date} is already maxed to #{maximum_hours} hours for #{user.login}."
        end
      end

      unless maxed_hours
        members = user.members.reject { |v| v.project.project_type != "Development" }

        members.each do |member|

          leaves.each do |leave|
            allocations = member.resource_allocations
            allocations.each do |allocation|
              if allocation.start_date <= leave && allocation.end_date >= leave &&
                  allocation.resource_allocation > 0
                @total_allocation = get_total_allocation(members, leave, "Billable")
                if member.project.accounting_type == "Billable"

                  if @total_allocation == 100 || @total_allocation < 100
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      timelog(leave, user, member, allocation)
                    end

                  elsif @total_allocation > 100
                    total_billable_allocation = get_total_allocation(members, leave, "Both")
                    total_shadow_allocation = get_total_allocation(members, leave, "Project Shadow")
                    if allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] || allocation.resource_type == Hash[ResourceAllocation::TYPES]["Non-billable"]
                      if total_billable_allocation >= 100 && total_shadow_allocation > 0
                        timelog(leave, user, member, allocation)
                      else
                        timelog_over_allocation(leave, user, member, allocation)
                      end
                    end
                  end
                end
              end
            end
          end
        end
        leaves.each do |leave|
          @total_spent_time = TimeEntry.find(:all, :conditions => ["user_id=? and spent_on=?", user.id, leave]).sum(&:hours).to_f
          engineer_admin_under_allocation(leave, user) if @total_spent_time < @number_of_hours
        end
      end
      render :json => {:success => @error.empty?, :error => @error}.to_json
    else
      render :json => {:success => false}.to_json
    end

  end


  private

  def timelog_over_allocation(leave, user, member, allocation)
    project = get_project(member)
    issue = get_leave_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours * allocation.resource_allocation/@total_allocation)
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def timelog(leave, user, member, allocation)
    project = get_project(member)
    issue = get_leave_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours * allocation.resource_allocation/100)
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def engineer_admin_under_allocation(leave, user)
    project = get_project()
    issue = get_leave_issue(project, user)
    hours_spent = "%.2f" % (@number_of_hours - @total_spent_time)
    save_time_entry(leave, issue, project, user, hours_spent)
  end

  def get_project(member=nil)
    unless member && member.project.accounting_type == "Billable"
      Project.find_by_identifier("existengradmn")
    else
      project_parent = member.project.parent
      project_parent ? project_parent.children.select { |v| v.project_type && v.project_type.downcase[/admin/] && v.status == 1 }[0] || member.project : member.project
    end
  end

  def get_leave_issue(project, user)
    support_tracker = Tracker.find_by_name("Support")
    task_tracker = Tracker.find_by_name("Task")
    issue = project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ? OR tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%LEAVE%", task_tracker.id, "%LEAVE%"])
    if issue.nil?
      issue = Issue.new
      issue.attributes = {"start_date" => "2012-01-01", "description" => "",
                          "estimated_hours" => "", "subject" => "Leaves", "priority_id" => "4",
                          "remaining_effort" => "", "done_ratio" => "0", "due_date" => "",
                          "acctg_type" => "10", "fixed_version_id" => "", "status_id" => "2",
                          "custom_field_values" => {"34" => "0"}, "assigned_to_id" => "#{user.id}",
                          "tracker_id" => "3", "project_id" => "#{project.id}", "author_id" => "#{user.id}"}
    end
    issue
  end

  def save_time_entry(leave, issue, project, user, hours_spent)
    if issue && project && user
      activity_id = Enumeration.find_by_name("Others").id
      new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                               :spent_on => leave, :activity_id => activity_id, :hours => hours_spent)
      new_time.comments = @comment
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
    allocation_total = 0
    unless allocations.empty?
      allocations.each do |allocation|
        if  allocation.start_date <= leave && allocation.end_date >= leave &&
            allocation.resource_allocation > 0
          case acctg
            when "Billable"
              allocation_total += allocation.resource_allocation if (allocation.resource_type == Hash[ResourceAllocation::TYPES]["Billable"] ||
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