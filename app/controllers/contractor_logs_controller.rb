class ContractorLogsController < ApplicationController

  before_filter :require_contractor_log

  def index
    @users = User.all.sort!{|x,y|x.login <=> y.login}.collect(&:login)
    @projects = Project.all.sort!{|x,y|x.identifier <=> y.identifier}.collect(&:identifier)
    @months = Date::MONTHNAMES
  end

  def create
      months = Date::MONTHNAMES
      user = User.find_by_login(params[:login][:login])
      project = Project.find_by_identifier params[:project][:identifier]
      if user and project
        params_start_date = to_date_safe(params[:start_date])
        params_end_date = to_date_safe(params[:end_date])
        start_date = params_start_date ? params_start_date : Date.new
        end_date = params_end_date ? params_end_date : Date.new
        loc = Holiday::LOCATIONS.select{|p,x| x == "#{user.location}"}.flatten[0]
        month = params[:month][:month].to_s
        year = params[:date][:year].to_i
        member = project.members.find_by_user_id user.id
        max = params[:hours][:time_entry].to_f
        issue = project.issues.select{|i| i.subject.downcase["generic tasks"]}.first
        if issue.nil?
          issue = Issue.new
          issue.attributes = {"start_date"=>"2012-01-01", "description"=>"",
                              "estimated_hours"=>"", "subject"=>"Generic Tasks", "priority_id"=>"4",
                              "remaining_effort"=>"", "done_ratio"=>"0", "due_date"=>"",
                              "acctg_type"=>"10", "fixed_version_id"=>"", "status_id"=>"2",
                              "custom_field_values"=>{"34"=>"0"}, "assigned_to_id"=>"#{user.id}",
                              "tracker_id"=>"3", "project_id"=>"#{project.id}", "author_id"=>"#{user.id}"}
          project.trackers << issue.tracker if !project.trackers.include? issue.tracker
        end

          if curr_month = months.index(month.strip)
            date = Date.new(year ? year : Date.current.year, curr_month,1)
            (date..date.end_of_month).each do |d|
              if d >= start_date and (1..5) === d.wday and detect_holidays_in_week(loc, d) == 0 and max > 0
                current_day_hours = TimeEntry.find(:all, :conditions=>["user_id=? and spent_on=?",user.id, d]).sum(&:hours).to_f
                if current_day_hours < max
                  h = max - current_day_hours
                  new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                                           :spent_on => d, :activity_id => 9, :hours => h)
                  new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
                  flash[:notice] = "Added #{h} hours on #{d.to_s} to #{issue.subject} of project #{project}" if new_time.save(false)
                else
                  flash[:error] = "Logs for #{d.to_s} is already maxed to #{max} hours."
                end
              end
            end
          elsif start_date
            start_month = start_date.month
            end_month = end_date.month
            date = Date.new(start_date.year, start_month,1)
            end_date = end_date ? Date.new(end_date.year, end_month,end_date.day) : date.end_of_month
            (date..end_date).each do |d|
              if d >= start_date and (1..5) === d.wday and detect_holidays_in_week(loc, d) == 0 and max > 0
                current_day_hours = TimeEntry.find(:all, :conditions=>["user_id=? and spent_on=?",user.id, d]).sum(&:hours).to_f
                if current_day_hours < max
                  h = max - current_day_hours
                  new_time = TimeEntry.new(:project => project, :issue => issue, :user => user,
                                           :spent_on => d, :activity_id => 9, :hours => h)
                  new_time.comments = "Logged spent time. Doing #{new_time.activity.name} on #{new_time.issue.subject}"
                  flash[:notice] = "Added #{h} hours on #{d.to_s} to #{issue.subject} of project #{project}" if new_time.save(false)
                else
                  flash[:error] = "Logs for #{d.to_s} is already maxed to #{max} hours."
                end
              end
            end
          end

      end

      redirect_to contractor_logs_path

  end

  private
  def require_contractor_log
    return unless require_login

    den_project = Project.find_by_name("New DEN Development").members(&:user_id)
    valid_usernames = ["gcordero"]
    den_project.each do |v|
      valid_usernames << User.find(v.user_id).login
    end

    unless valid_usernames.include? User.current.login
      render_403
      return false
    end
    true
  end

  def detect_holidays_in_week(location, day)
    locations = [6]
    locations << location if location
    locations << 3 if location.eql?(1) || location.eql?(2)
    Holiday.count(:all, :conditions => ["event_date=? and location in (#{locations.join(', ')})", day])
  end

end