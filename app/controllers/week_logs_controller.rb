class WeekLogsController < ApplicationController
  before_filter :get_week_start, :only => [:add_task, :load_tables]
  before_filter :find_user_projects, :only => [:add_task, :load_tables]
  before_filter :find_time_entries, :only => [:add_task, :load_tables]
  before_filter :get_projnames_and_iterations, :only => [:index, :load_tables]
  require 'json'
  
  def index
    @all_project_names = ["All"] + (get_all_project_names()).uniq
    @tracker_names = ["All", "Bug", "Feature", "Support", "Task"]
  end
  
  def load_tables
    @issues = {}
    if params[:load_type] == "project"
      proj_cache = read_proj_cache()
      if params[:proj_dir]
        case params[:proj_dir]
          when "" then params[:proj_dir] = "asc"
          when "asc" then params[:proj_dir] = "desc"
          when "desc" then params[:proj_dir] = "asc"
        end
      end
      @issues[:project_related] = proj_cache ? Issue.find(proj_cache) : Issue.assigned_to(@user).in_projects(@projects[:non_admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC") 
      @issues[:project_related] = (@issues[:project_related] + @time_issues[:non_admin]).uniq
      write_to_proj_cache(@issues[:project_related].map(&:id).uniq)
      @issues[:project_related] = sort(@issues[:project_related], params[:proj], params[:proj_dir], params[:f_tracker], params[:f_proj_name])
      @proj_issues = nil 
    elsif params[:load_type] == "admin"
      non_proj_cache = read_non_proj_cache()
      if params[:non_proj_dir]
        case params[:non_proj_dir]
          when "" then params[:non_proj_dir] = "asc"
          when "asc" then params[:non_proj_dir] = "desc"
          when "desc" then params[:non_proj_dir] = "asc"
        end
      end
      @issues[:non_project_related] = non_proj_cache ? Issue.find(non_proj_cache) : Issue.in_projects(@projects[:admin]).all(:order => "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC")
      @issues[:non_project_related] = (@issues[:non_project_related] + @time_issues[:admin]).uniq
      write_to_non_proj_cache(@issues[:non_project_related].map(&:id).uniq)
      @issues[:non_project_related] = sort(@issues[:non_project_related], params[:non_proj], params[:non_proj_dir], params[:f_tracker], params[:f_proj_name])
      @non_proj_issues = nil
    end

    respond_to do |format|
      format.js {render :layout => false}
    end
  end

  def update
    error_messages = {}
    error_messages[:project] = SaveWeekLogs.save(params[:project] || {}, User.current, Date.parse(params[:startdate]))
    error_messages[:non_project] = SaveWeekLogs.save(params[:non_project] || {}, User.current, Date.parse(params[:startdate]))
    render :json => error_messages.to_json
  end

  def add_task
    proj_cache, non_proj_cache = read_cache()
    issues_order = "#{Issue.table_name}.project_id DESC, #{Issue.table_name}.updated_on DESC"
    issues = { 'project' => Issue.in_projects(@projects[:non_admin]).all(:order => issues_order).concat(@time_issues[:non_admin]).uniq,
               'admin' => Issue.in_projects(@projects[:admin]).all(:order => issues_order).concat(@time_issues[:admin]) }
    respond_to do |format|
      format.js do
        error_messages, proj_cache, non_proj_cache = WeekLogsHelper.add_task(proj_cache, non_proj_cache, issues, params)
        write_to_cache(proj_cache, non_proj_cache)
        if !error_messages.empty?
          render :text => "#{JSON error_messages.uniq}", :status => 400
        else
          head :created
        end
      end
    end
  end

  def remove_task
    proj_cache, non_proj_cache = read_cache()
    respond_to do |format|
      format.html { redirect_to '/week_logs' }
      format.js do
        issue_id = params[:id].map {|x| x.to_i}
        issue_id.each do |id|
          proj_cache.delete id
          non_proj_cache.delete id
        end
        write_to_cache(proj_cache, non_proj_cache)
        head :ok
      end
    end
  end
  
  def task_search
    project_names, non_project_names = [], []
    if params[:type] ==  "project"
      proj_cache = read_proj_cache()
      project_names = get_project_names()
      @proj_issues = WeekLogsHelper.task_search(params, project_names, proj_cache)
    else
      non_proj_cache = read_non_proj_cache()
      non_project_names = get_non_project_names()
      @non_proj_issues = WeekLogsHelper.task_search(params, non_project_names, non_proj_cache)
    end

    respond_to do |format|
      format.js { render :layout => false}
    end
  end
  
  def iter_refresh
    project = Project.find_by_name params[:project]
    @iter_proj = ["All Issues"] + project.versions.sort_by(&:created_on).reverse.map {|z| z.name}
    respond_to do |format|
      format.js { render :layout => false}
    end
  end

  private
    
    def write_to_proj_cache(proj_cache)
      $redis.set "project_issue_ids_#{User.current.id}", JSON(proj_cache)
    end

    def write_to_non_proj_cache(non_proj_cache)
      $redis.set "non_project_issue_ids_#{User.current.id}", JSON(non_proj_cache)
    end

    def write_to_cache(proj_cache, non_proj_cache)
      $redis.set "project_issue_ids_#{User.current.id}", JSON(proj_cache)
      $redis.set "non_project_issue_ids_#{User.current.id}", JSON(non_proj_cache)
    end
    
    def read_proj_cache
      proj_cache = $redis.get "project_issue_ids_#{User.current.id}"
      proj_cache ? proj_cache = JSON(proj_cache) : proj_cache = nil
    end

    def read_non_proj_cache
      non_proj_cache = $redis.get "non_project_issue_ids_#{User.current.id}"
      non_proj_cache ? non_proj_cache = JSON(non_proj_cache) : non_proj_cache = nil
    end

    def read_cache
      proj_cache = $redis.get "project_issue_ids_#{User.current.id}"
      proj_cache ? proj_cache = JSON(proj_cache) : proj_cache = []
      non_proj_cache = $redis.get "non_project_issue_ids_#{User.current.id}"
      non_proj_cache ? non_proj_cache = JSON(non_proj_cache) : non_proj_cache = [] 
      [proj_cache, non_proj_cache]
    end

    def get_week_start
      params[:week_start] == nil ? @week_start = Date.current : @week_start = Date.parse(params[:week_start])
      @week_start = @week_start.beginning_of_week
    end

    def find_user_projects
      @user = User.current
      project_related = @user.projects.select{ |project| !project.project_type.to_s.downcase['admin'] }
      non_project_related = @user.projects.select{ |project| project.project_type.to_s.downcase['admin'] }
      if non_project_related.length > 1
        non_project_related.delete(Project.find_by_name('Exist Engineering Admin'))
      end
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
          when 'task_activity' then array = array.sort_by {|i| i.id}
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
    
    def get_all_project_names
      User.current.projects.select{|z| !z.issues.empty? && z.status == Project::STATUS_ACTIVE}.map(&:name).sort_by{|i| i.downcase}
    end

    def get_project_names
      User.current.projects.select{|z| !z.project_type.to_s.downcase['admin'] && !z.issues.empty? && z.status == Project::STATUS_ACTIVE}.map(&:name).sort_by{|i| i.downcase}
    end

    def get_non_project_names
      User.current.projects.select{|z| z.project_type.to_s.downcase['admin'] && !z.issues.empty? && z.status == Project::STATUS_ACTIVE}.map(&:name).sort_by{|i| i.downcase}
    end

    def get_projnames_and_iterations
      @project_names = get_project_names()
      if !@project_names.empty?
        @iter_proj = ["All Issues"] + Project.find_by_name(@project_names.first).versions.sort_by(&:created_on).reverse.map {|z| z.name}
      else
        @iter_proj = ["All Issues"]
      end
      @project_names = ["All Projects"] + @project_names
      @non_project_names = ["All Projects"] + get_non_project_names() 
    end
end
