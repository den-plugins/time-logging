module SaveWeekLogs

  def self.save(hash, user, week_start)
    error_messages = {}
    hash.each_key do |issue|
      error_messages[issue] = ""
      proj_issue = Issue.find(issue)
      project = proj_issue.project
      flag = false
      if project.accounting
        project.accounting.name=="Billable" ? issue_is_billable = true : issue_is_billable = false
      else
        issue_is_billable = false
      end
      member = project.members.select {|member| member.user_id == user.id} 
      if(issue_is_billable && 
         member.first && member.first.billable)#user is member and billable + issue is billable
        flag = true
      elsif(!issue_is_billable && 
            member.first)#user is member + issue is not billable
        flag = true
      end
      
      if(project.billing_model && project.billing_model.scan(/^(Fixed)/).flatten.present?)
        budget_computation(project.id, hash[issue], week_start)
        if (@project_budget - @actuals_to_date) < 0 && issue_is_billable#budget is consumed
          flag = false
          error_messages[issue] += "#{project.name}'s budget has already been consumed."
        end      
      end
      
      if(!member.first)
        error_messages[issue] += "User is not a member of #{project.name}."
      else
        if(issue_is_billable && !member.first.billable)
          error_messages[issue] += "User is not billable in #{project.name}."
        end
      end
      
      error_messages.delete(issue) if error_messages[issue]==""
      
      hash[issue].each_key do |date|
        time_entry = TimeEntry.find(:all, :conditions => ["user_id=? AND issue_id=? AND spent_on=?", user.id, issue, Date.parse(date)])
        hours = hash[issue][date]['hours'].to_hours
        total_time_entry = TimeEntry.sum(:hours, :conditions => ["user_id=? AND spent_on=?", user.id, Date.parse(date)])
        total_time_entry += hours
        if time_entry.empty?
          if(hours > 0 && flag)
            new_time = TimeEntry.new(:project => proj_issue.project, :issue => proj_issue, :user => User.current)
            new_time.hours = hours
            new_time.spent_on = Date.parse(date)
            new_time.activity_id = 9
            new_time.save!
          end
        else
          if(hours > 0 && flag)
            time_entry.first.hours = hours
            time_entry.first.save!
          elsif(hours<=0)
            time_entry.first.destroy
          end
        end
      end
    end
    error_messages
  end
  
  def self.budget_computation(project_id, eval_dates, week_start)
    project = Project.find(project_id)
    bac_amount = project.project_contracts.all.sum(&:amount)
    contingency_amount = 0
    @actuals_to_date = 0
    @project_budget = 0

    pfrom, afrom, pto, ato = project.planned_start_date, project.actual_start_date, project.planned_end_date, project.actual_end_date
    to = (ato || pto)

    if pfrom && to
      team = project.members.project_team.all
      reporting_period = week_start.end_of_week
      forecast_range = get_weeks_range(pfrom, to)
      actual_range = get_weeks_range((afrom || pfrom), reporting_period)
      cost = project.monitored_cost(forecast_range, actual_range, team, eval_dates, project_id)
      actual_list = actual_range.collect {|r| r.first }
      cost.each do |k, v|
        if actual_list.include?(k.to_date)
          @actuals_to_date += v[:actual_cost]
        end
      end
      @project_budget = bac_amount + contingency_amount
    end
  end
end
