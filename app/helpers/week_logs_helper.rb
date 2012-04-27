module WeekLogsHelper
  def week_dates(date=Date.today)
    date = @week_start || date
    date.beginning_of_week..date.end_of_week
  end

  def week_days
    %w[mon tue wed thu fri sat sun]
  end

  def sortable(column, type, title=nil)
    title ||= column.titleize
    direction = (column == params[type] && params["#{type}_dir"] == "asc") ? "desc" : "asc"
    if column == params[type]
      link_to title, {:"#{type}"=> column, :"#{type}_dir" => direction}, {:class=>"#{type} #{params["#{type}_dir"]} #{title.downcase.gsub('/', '_')}"}
    else
      link_to title, {:"#{type}"=> column, :"#{type}_dir" => direction}, {:class=>"#{type} #{title.downcase.gsub('/', '_')}"}
    end
  end

  def self.add_task(proj_cache, non_proj_cache, issues, params)
    error_messages = []
    user = User.current
    issue_type = params[:type].to_s
    date = Date.parse(params[:week_start])
    params[:id].each do |id|
      alloc_flag = false
      b_alloc_flag = false
      issue_id = id.to_i
      issue = issues[issue_type].find {|param| param.id == issue_id}
      if issue_type == 'admin'
        if issue = Issue.find(issue_id)
          project = issue.project
          issue = nil if !(issue_type == 'admin' && project.project_type.downcase['admin'])
        end
      end
      if issue
        project = issue.project
        admin_flag = project.project_type.to_s.downcase['admin']
        if issue.acctg_type
          issue_is_billable = (issue.acctg_type == Enumeration.find_by_name('Billable').id) ? true : false
        else
          issue_is_billable = false
        end
        member = project.members.select {|member| member.user_id == user.id}.first
        
        if member
          (date..date.end_of_week).each do |d|
            alloc_flag=true if member.allocated? d
            b_alloc_flag=true if member.b_alloc? d
          end
        end
        if !issue_is_billable && member && !alloc_flag && !admin_flag 
          error_messages << "You are not allocated in issue ##{issue.id} for this week."
        elsif issue_is_billable && member && !b_alloc_flag && !admin_flag
          error_messages << "You are not billable in issue ##{issue.id} for this week."
        elsif !member
          error_messages << "You are not a member of #{issue.project.name}." 
        else
          case issue_type
            when 'project'
              proj_cache << issue_id
            when 'admin'
              non_proj_cache << issue_id
          end
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
          error_messages << "You are not allowed to log time in issue ##{issue_id}."
        else
          error_messages << "Issue ##{issue_id} does not exist."
        end
      end
    end
    [error_messages, proj_cache, non_proj_cache]
  end

  def self.task_search(params, project_names)
    result = []
    project = Project.find_by_name params[:project]
    iter = params[:iter]
    type = params[:type]
    issue_id = params[:task]
    iter =~ /All Issues/ ? iter = "all" : iter = project ? project.versions.find_by_name(iter) : []
    input = params[:search]
    id_arr = [input.scan(/\d+/).map{|z| z[0..9].to_i}, params[:task].scan(/\d+/).map{|z| z[0..9].to_i}]
    subject = input.scan(/[a-zA-Z]+/).join " "
    existing = params[:exst]
    existing ? existing.map!{|z| Issue.find_by_id z.to_i} : existing = []
    
    if project && issue_id == "" && input == "" #default; for displaying all issues
      if iter == "all"
        result += project.issues 
      else
        result += iter.fixed_issues
      end
    elsif params[:project].downcase['all projects'] #searches in all projects
      project_names.each do |name|
        project = Project.find_by_name name 
        if subject != "" 
          result += project.issues.find :all, :conditions => ["subject ILIKE ?", "%#{subject}%"]
        else
          result += project.issues
        end
        id_arr.each do |arr|
          if !arr.empty? 
            arr.each do |id|  
              num = project.issues.find_by_id id
              result << num if num
            end
          end
        end
      end
    else  #searches in selected iteration
      if subject != ""
        if iter == "all"
          result += project.issues.find :all, :conditions => ["subject ILIKE ?", "%#{subject}%"]
        elsif iter != "all"
          result += iter.fixed_issues.find :all, :conditions => ["subject ILIKE ?", "%#{subject}%"]
        end
      end
      id_arr.each do |arr|
        if !arr.empty? 
          arr.each do |id|
            if iter == "all"
              num = project.issues.find_by_id id
            elsif iter != "all"
              num = iter.fixed_issues.find_by_id id
            end
            result << num if num
          end
        end
      end
    end
    [result.select{|y| !existing.include?(y)}.sort_by(&:id).uniq, result.select{|y| existing.include?(y)}.sort_by(&:id).uniq]
  end
end
