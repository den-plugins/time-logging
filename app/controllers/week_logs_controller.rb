class WeekLogsController < ApplicationController

  def index
    @user = User.current
    issues = Issue.open.visible.assigned_and_loggable_to(@user).all(
      :include => [ :status, :project, :tracker, :priority ],
      :order => "#{Project.table_name}.id DESC, #{Enumeration.table_name}.position DESC")
    @project_issues = issues.select { |i| i.project.name !~ /admin/i }
    @non_project_issues = issues.select { |i| i.project.name =~ /admin/i }
    respond_to do |format|
      format.html
      format.json do
        render :json => { :issues => {
                            :project_issues => @project_issues.map(&:to_json),
                            :non_project_issues => @non_project_issues.map(&:to_json) } }
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
