class WeekLogsController < ApplicationController

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
  end

  def destroy
  end

end