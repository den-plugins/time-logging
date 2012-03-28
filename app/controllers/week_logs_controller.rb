class WeekLogsController < ApplicationController
  before_filter :get_week_start, :only => [:index, :add_task]
  before_filter :find_user_projects, :only => [:index, :add_task]
  before_filter :find_time_entries, :only => [:index, :add_task]
  require 'json'

  def index
    @issues = { :project_related => session[:project_issue_ids] ? Issue.find(session[:project_issue_ids]) : Issue.open.visible.assigned_to(@user).in_projects(@projects[:non_admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"),
                :non_project_related => session[:non_project_issue_ids] ? Issue.find(session[:non_project_issue_ids]) : Issue.open.visible.in_projects(@projects[:admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC") }
    session[:project_issue_ids] = @issues[:project_related].map(&:id).uniq
    session[:non_project_issue_ids] = @issues[:non_project_related].map(&:id).uniq
    @issues[:project_related] = (@issues[:project_related] + @time_issues[:non_admin]).uniq
    @issues[:non_project_related] = (@issues[:non_project_related] + @time_issues[:admin]).uniq
    respond_to do |format|
      format.html
      format.json do
        render :json => @issues.to_json
      end
      format.js { render :layout => false}
    end
  end

  def update
    error_messages = {}
    error_messages[:project] = SaveWeekLogs.save(JSON(params[:project]), User.current)
    error_messages[:non_project] = SaveWeekLogs.save(JSON(params[:non_project]), User.current)
    render :json => error_messages.to_json
  end

  def add_task
    @user = User.current
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        return render(:text => "Issue ID is required.", :status => 400) if params[:id].blank?
        begin
          issue_id = params[:id].to_i
          issue_type = params[:type].to_s
          issues_order = "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"
          issues = { 'project' => Issue.open.visible.in_projects(@projects[:non_admin]).all(:order => issues_order).concat(@time_issues[:non_admin]).uniq,
                     'admin' => Issue.in_projects(@projects[:admin]).all(:order => issues_order).concat(@time_issues[:admin]) }
          @issue = issues[issue_type].find {|param| param.id == issue_id}
          @total = 0 #placeholder

          if @issue
            project = @issue.project
            if project.accounting
              project.accounting.name=="Billable" ? issue_is_billable = true : issue_is_billable = false
            else
              issue_is_billable = false
            end
            member = project.members.select {|member| member.user_id == @user.id}
            if(issue_is_billable && member.first && !member.first.billable)
              render :text => "You are not billable in #{@issue.project.name}.", :status => 400
            elsif(!member.first)
              render :text => "You are not a member of #{@issue.project.name}.", :status => 400
            else
              case issue_type
                when 'project'
                  session[:project_issue_ids] ||= []
                  session[:project_issue_ids] << issue_id
                when 'admin'
                  session[:non_project_issue_ids] ||= []
                  session[:non_project_issue_ids] << issue_id
              end
              head :created
            end
          else
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
        end
      end
    end
  end

  def remove_task
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        issue_id = params[:id].to_i
        session[:project_issue_ids].delete(issue_id)
        session[:non_project_issue_ids].delete(issue_id)
        head :ok
      end
    end
  end

  private

    def get_week_start
      params[:week_start] == nil ? @week_start = Date.current : @week_start = Date.parse(params[:week_start])
      @week_start = @week_start.beginning_of_week
    end

    def find_user_projects
      @user = User.current
      project_related = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) && project.name !~ /admin/i && project.project_type.to_s !~ /admin/i }
      non_project_related = @user.projects.select{ |project| @user.role_for_project(project).allowed_to?(:log_time) && project.name.downcase['admin'] && project.project_type.to_s.downcase['admin'] }
      if non_project_related.empty?
        non_project_related = @user.projects.select{ |p| @user.role_for_project(p).allowed_to?(:log_time) && p.project_type &&  p.project_type.to_s.downcase.include?("admin") && @user.member_of?(p)}.flatten.uniq
      end
      non_project_related.delete(Project.find_by_name('Exist Engineering Admin'))
      @projects = { :non_admin => project_related, :admin => non_project_related }
    end

    def find_time_entries
      @user ||= User.current
      non_proj_default = Project.find_by_name('Exist Engineering Admin')
      time_entry = TimeEntry.all(:conditions => ["spent_on BETWEEN ? AND ? AND user_id=?", @week_start, @week_start.end_of_week, @user.id])
      issues = time_entry.map(&:issue)
      proj = issues.select { |i| i.project.name !~ /admin/i && i.project.project_type.to_s !~ /admin/i }
      non_proj = issues.select { |i| i.project.project_type && i.project.project_type["Admin"]}
      non_proj += Issue.in_projects(non_proj_default) if @projects[:admin].empty?
      @time_issues = {:non_admin => proj, :admin => non_proj }
    end
end
