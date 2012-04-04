module SaveWeekLogs

  def self.save(hash, user, startdate)
    start_d = startdate.beginning_of_week
    startdate.end_of_week > Date.current ? end_d = Date.current : end_d = startdate.end_of_week
    hash, msg = budget_computation(hash)
    error_messages =  msg
    hash.each_key do |issue|
      error_messages[issue] = ""
      proj_issue = Issue.find(issue)
      project = proj_issue.project
      member = project.members.select {|member| member.user_id == user.id} 
      flag = false
      if proj_issue.acctg_type
        issue_is_billable = (proj_issue.acctg_type == Enumeration.find_by_name('Billable').id) ? true : false
      else
        issue_is_billable = false
      end
      if(!member.first)
          error_messages[issue] += "User is not a member of #{project.name}."
      end

      hash[issue].each_key do |date|
        time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", user.id, issue, Date.parse(date)])
        hours = hash[issue][date].to_hours
        total_time_entry = TimeEntry.sum(:hours, :conditions => ["user_id=? AND spent_on=?", user.id, Date.parse(date)])
        total_time_entry += hours
        if(issue_is_billable && member.first)
          if(member.first.allocated?(Date.parse(date)))#user is member and billable + issue is billable
            flag = true
          else
            error_messages[issue] += "User is not allocated/billable in #{project.name} on #{Date.parse(date).strftime("%m/%d/%Y")}."
            flag = false
          end
        elsif(!issue_is_billable && member.first)#user is member but not billable
          if(!member.first.resource_allocations.empty?)
            flag=true
          else
            error_messages[issue] += "User has not been allocated in #{project.name}."
            flag=false
          end
        end
        if(hours > 0 && flag)
          time_entry.each {|te| te.destroy} if !time_entry.empty?
          new_time = TimeEntry.new(:project => proj_issue.project, :issue => proj_issue, :user => User.current)
          new_time.hours = hours
          new_time.spent_on = Date.parse(date)
          new_time.activity_id = 9
          new_time.save!
        elsif(hours == 0 && flag)
          time_entry.each {|te| te.destroy}
        end
      end

      error_messages.delete(issue) if error_messages[issue]==""
    end
    error_messages
  end
  
  def self.cleaner(hash, project_id)
    hash.each do |id|
      issue = Issue.find id
      hash.delete(id) if issue.project.id == project_id
    end
    hash
  end
  
  def self.future_dates(hash, project, issue)
    total = 0
    member = project.members.find(:all, :conditions=>["members.user_id=?", User.current.id]).first
    member ? rate = member.internal_rate.to_f : rate = 0.0
    hash.keys.each do |date|
      time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", User.current.id, issue, date])  
      total += hash[date].to_f * rate
    end
    total
  end
  
  def self.budget_computation(hash)
    error_messages = {}
    proj = hash.keys.map {|issue| Issue.find(issue).project}.uniq
    proj.each do |project|
      if(project.billing_model && project.billing_model.scan(/^(Fixed)/).flatten.present?)
        keys = hash.keys.map {|issue| issue if Issue.find(issue).project.id == project.id}.compact
        bac_amount = project.project_contracts.all.sum(&:amount)
        contingency_amount = 0
        @actuals_to_date = 0
        @project_budget = 0

        pfrom, afrom, pto, ato = project.planned_start_date, project.actual_start_date, project.planned_end_date, project.actual_end_date
        to = (ato || pto)

        if pfrom && to
          team = project.members.project_team.all
          reporting_period = Date.today.end_of_week
          forecast_range = get_weeks_range(pfrom, to)
          actual_range = get_weeks_range((afrom || pfrom), reporting_period)
          cost = project.monitored_cost(forecast_range, actual_range, team)
          actual_list = actual_range.collect {|r| r.first }
          cost.each do |k, v|
            if actual_list.include?(k.to_date)
              @actuals_to_date += v[:actual_cost]
            end
          end
          @project_budget = bac_amount + contingency_amount
          keys.each do |key|
            if project.accounting
              project.accounting.name=="Billable" ? billable = true : billable = false
            else
              billable = false
            end
            if((@project_budget - (@actuals_to_date + future_dates(hash[key], project, key))) < 0 && billable)
              error_messages[key] = "#{project.name}'s budget has already been consumed."
              hash.delete key
            end
          end
        end
      end
    end
    [hash, error_messages]
  end
end
