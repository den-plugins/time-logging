class WeekLogsController < ApplicationController

  require 'json'
  
  def index
    @user = User.current
    projects = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) }
    project_related, non_project_related = projects.partition{ |p| p.name !~ /admin/i }
    @projects = { :non_admin => project_related, :admin => non_project_related }
    @issues = { :project_related => Issue.open.visible.assigned_to(@user).in_projects(@projects[:non_admin]),
                :non_project_related => Issue.in_projects(@projects[:admin]) }
    respond_to do |format|
      format.html
      format.json do
        render :json => @issues.to_json
      end
    end
  end

  def create
  end

  def show
  end

  def edit
  end

  def update
    project = JSON params[:project]
    non_project = JSON params[:non_project]
    user = User.current
    project.each_key do |issue|
      project[issue].each_key do |date|
        time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", user.id, issue, Date.parse(date)])
        if time_entry.empty?
          if(project[issue][date]['hours'].match(/\d+/))
            proj_i = Issue.find(issue)
            new_time = TimeEntry.new(:project => proj_i.project, :issue => proj_i, :user => User.current)
            new_time.hours = Float project[issue][date]['hours']
            new_time.spent_on = Date.parse(date)
            new_time.activity_id = 9
            new_time.save!
          end
        else
          time_entry.first.hours = Float project[issue][date]['hours'] rescue time_entry.first.hours = 0
          time_entry.first.save!
        end
      end      
    end
    render :nothing=>true
  end

  def destroy
  end

end
