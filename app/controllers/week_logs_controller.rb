class WeekLogsController < ApplicationController
  before_filter :get_week_start, :only => [:index, :add_task]
  before_filter :find_user_projects, :only => [:index, :add_task]

  require 'json'

  def index
    @issues = { :project_related => session[:project_issue_ids] ? Issue.find(session[:project_issue_ids]) : Issue.open.visible.assigned_to(@user).in_projects(@projects[:non_admin]),
                :non_project_related => session[:non_project_issue_ids] ? Issue.find(session[:non_project_issue_ids]) : Issue.in_projects(@projects[:admin]) }
    session[:project_issue_ids] = @issues[:project_related].map(&:id).uniq
    session[:non_project_issue_ids] = @issues[:non_project_related].map(&:id).uniq
    respond_to do |format|
      format.html
      format.json do
        render :json => @issues.to_json
      end
      format.js { render :layout => false}
    end
  end

  def create
  end

  def show
  end

  def edit
  end

  def update
    SaveWeekLogs.save(JSON(params[:project]), User.current)
    SaveWeekLogs.save(JSON(params[:non_project]), User.current)
    render :nothing=>true
  end

  def destroy
  end

  def add_task
    return render(:text => "Issue ID is required.", :status => 400) if params[:id].blank?
    issue_id = params[:id].to_i
    issue_type = params[:type].to_s
    issues = { 'project' => Issue.open.visible.in_projects(@projects[:non_admin]),
               'admin' => Issue.in_projects(@projects[:admin]) }
    @issue = issues[issue_type].find(issue_id)
    @total = 0 #placeholder
    case issue_type
    when 'project'
      session[:project_issue_ids] ||= []
      session[:project_issue_ids] << issue_id
    when 'admin'
      session[:non_project_issue_ids] ||= []
      session[:non_project_issue_ids] << issue_id
    end
    # render :partial => '/week_logs/partials/week', :locals => { :issue => @issue }
    head :created
  rescue ActiveRecord::RecordNotFound
    other_issues = case issue_type
                   when 'admin'
                     issues['project']
                   when 'project'
                     issues['admin']
                   end
    if other_issues.map(&:id).include? issue_id
      phrase = (issue_type == 'admin' ? 'an admin' : 'a project')
      render :text => "Issue ##{issue_id} is not #{phrase} task.", :status => 400
    elsif Issue.exists? issue_id
      render :text => "You are not allowed to log time to issue ##{issue_id}.", :status => 400
    else
      render :text => "Issue ##{issue_id} does not exist.", :status => 404
    end
  end

  def remove_task
    issue_id = params[:id].to_i
    session[:project_issue_ids].delete(issue_id)
    session[:non_project_issue_ids].delete(issue_id)
    head :ok
  end

  private

    def get_week_start
      params[:week_start] == nil ? @week_start = Date.current : @week_start = Date.parse(params[:week_start])
      @week_start = ((@week_start-6)..(@week_start+6)).find{|wk| wk.cwday == 1}
    end

    def find_user_projects
      @user = User.current
      projects = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) }
      project_related, non_project_related = projects.partition{ |p| p.name !~ /admin/i }
      non_project_related = non_project_related.first || Project.find_by_name('Exist Engineering Admin')
      @projects = { :non_admin => project_related, :admin => non_project_related }
    end
end