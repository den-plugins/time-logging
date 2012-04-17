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
    @issues[:project_related] = sort(@issues[:project_related], params[:proj], params[:proj_dir], params[:f_tracker], params[:f_proj_name])

    @issues[:non_project_related] = (@issues[:non_project_related] + @time_issues[:admin]).uniq
    @issues[:non_project_related] = sort(@issues[:non_project_related], params[:non_proj], params[:non_proj_dir], params[:f_tracker], params[:f_proj_name])
    
    @all_project_names = (@issues[:project_related] + @issues[:non_project_related]).map {|i| i.project.name}.uniq.sort_by {|i| i.downcase}
    @tracker_names = (@issues[:project_related] + @issues[:non_project_related]).map {|i| i.tracker.name}.uniq.sort_by {|i| i.downcase}
    
    @project_names = @issues[:project_related].map {|i| i.project.name}.uniq.sort_by {|i| i.downcase}
    @iter_proj = Project.find_by_name(@project_names.first).versions.sort_by(&:id)
    @iter_proj.empty? ? @proj_issues = nil : @proj_issues = @iter_proj.first.fixed_issues.select {|x| x.loggable?(User.current) || x.assigned_to == User.current}.sort_by(&:id)
    
    @non_project_names = @issues[:non_project_related].map {|i| i.project.name}.uniq.sort_by {|i| i.downcase}
    @non_project_names.empty? ? @non_proj_issues = nil : @non_proj_issues = Project.find_by_name(@non_project_names.first).issues.select {|x| x.loggable? User.current}.sort_by(&:id)
    
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
    error_messages[:project] = SaveWeekLogs.save(params[:project] || {}, User.current, Date.parse(params[:startdate]))
    error_messages[:non_project] = SaveWeekLogs.save(params[:non_project] || {}, User.current, Date.parse(params[:startdate]))
    render :json => error_messages.to_json
  end

  def add_task
    @user = User.current
    error_messages = []
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        params[:id].each do |id|
          issue_id = id.to_i
          issue_type = params[:type].to_s
          issues_order = "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"
          issues = { 'project' => Issue.open.visible.in_projects(@projects[:non_admin]).all(:order => issues_order).concat(@time_issues[:non_admin]).uniq,
                     'admin' => Issue.in_projects(@projects[:admin]).all(:order => issues_order).concat(@time_issues[:admin]) }
          @issue = issues[issue_type].find {|param| param.id == issue_id}
          issue_type == 'admin' ? @issue = Issue.find(issue_id) :  @issue = issues[issue_type].find {|param| param.id == issue_id}
          @total = 0 #placeholder

          if @issue
            project = @issue.project
            if project.accounting
              project.accounting.name=="Billable" ? issue_is_billable = true : issue_is_billable = false
            else
              issue_is_billable = false
            end
            member = project.members.select {|member| member.user_id == @user.id}.first
            puts member
            puts issue_is_billable
            puts member.billable
            if(issue_is_billable && member && !member.billable)
              error_messages << "You are not billable/allocated in #{@issue.project.name}."
            elsif(!member)
              error_messages << "You are not a member of #{@issue.project.name}." 
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
              error_messages << "Issue ##{issue_id} is not #{phrase} task."
            elsif Issue.exists? issue_id
              error_messages << "You are not allowed to log time to issue ##{issue_id}."
            else
              error_messages << "Issue ##{issue_id} does not exist."
            end
          end
        end
          puts error_messages.inspect
          if !error_messages.empty?
            render :text => error_messages.uniq.join, :status => 400
          end
      end
    end
  end

  def remove_task
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        issue_id = params[:id].map {|x| x.to_i}
        issue_id.each do |id|
          session[:project_issue_ids].delete(id)
          session[:non_project_issue_ids].delete(id)
        end
        puts session[:project_issue_ids].inspect
        head :ok
      end
    end
  end
  
  def task_search
    respond_to do |format|
      format.js
    end
  end

  def iter_refresh
    project = Project.find_by_name params[:project]
    @iter_proj = project.versions.sort_by(&:id)
    if(params[:iter])
      iter = params[:iter].gsub(/\D+/, "").to_i - 1
      @proj_issues = @iter_proj[iter].fixed_issues.select {|x| x.loggable? User.current || x.assigned_to == User.current}
    else
      @iter_proj.empty? ? @proj_issues = nil : @proj_issues = @iter_proj.first.fixed_issues.select {|x| x.loggable? User.current}
    end
    respond_to do |format|
      format.js { render :layout => false}
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

    def sort(array, column, direction, tracker, proj_name)
      array = array.sort_by {|i| i.project.name.downcase}
      if column
        case column
          when 'subject' then array = array.sort_by {|i| i.id}
        end
      end
      if tracker && tracker.downcase != 'all'
        array.reject! {|i| i.tracker.name.downcase != tracker.downcase}
      end 
      if proj_name && proj_name.downcase != 'all'
        array.reject! {|i| i.project.name.downcase != proj_name.downcase}
      end
      direction == 'desc' ? array.reverse : array
    end
end
