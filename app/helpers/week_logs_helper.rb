module WeekLogsHelper
  def week_dates(date=Date.today)
    date = @week_start || date
    date.beginning_of_week..date.end_of_week
  end

  def week_days
    %w[mon tue wed thu fri sat sun]
  end
end