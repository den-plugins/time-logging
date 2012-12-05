class LeaveLogsController < ApplicationController

  before_filter :require_login, :except => [:save_leaves]
  skip_before_filter :check_if_login_required, :only => [:save_leaves]
  before_filter :restrict_access, :only => [:save_leaves]

  def save_leaves
    # params : username(string), date_from(date), date_to(date), half_day(boolean)
    if params[:username] && params[:date_from] && params[:date_to]
      @error = []
      leaves = (params[:date_from].to_datetime..params[:date_to].to_datetime)
      user = User.find_by_login(params[:username])
      number_of_hours = params[:half_day] == 1 ? 4 : 8
      members = user.members
      total_allocation = 0
      support_tracker = Tracker.find_by_name("Support")
      members.each do |member|
        project_parent = member.project.parent
        project = project_parent ? project_parent.children.select { |v| v.identifier.to_s.downcase[/admin|na/] }[0] || member.project : member.project
        issue = project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%LEAVE%"])
        allocations = member.resource_allocations

        allocations.each do |alloc|
          leaves.each do |leave|
            if alloc.start_date <= leave && alloc.end_date >= leave && alloc.resource_allocation > 0

              if alloc.resource_type == Hash[ResourceAllocation::TYPES]["Billable"]
                hours_spent = number_of_hours * alloc.resource_allocation/100
                total_allocation =+alloc.resource_allocation
                save_time_entry(leave, issue, project, user, hours_spent)
              else
                project = Project.find_by_identifier("existengradmn")
                issue = project.issues.find(:first, :conditions => ["tracker_id = ? AND upper(subject) LIKE ?", support_tracker.id, "%LEAVE%"])
                hours_spent = number_of_hours * alloc.resource_allocation/100
                total_allocation =+alloc.resource_allocation
                save_time_entry(leave, issue, project, user, hours_spent)
              end

            end
          end
        end
      end
      render :json => {:success => @error.empty?, :error => @error}.to_json
    else
      render :json => {:success => false}.to_json
    end

  end

  private

  def save_time_entry(leave, issue, project, user, hours_spent)
    if issue && project && user
      new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                               :spent_on => leave, :activity_id => 9, :hours => hours_spent)
      new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
      @error << new_time.errors unless new_time.save
    end
  end

  def restrict_access
    head :unauthorized unless params[:access_token].eql? AUTH_TOKEN
  end

end