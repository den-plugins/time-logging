module WeekLogsHelper
  def week_dates(date=Date.today)
    date = @week_start || date
    date.beginning_of_week..date.end_of_week
  end

  def week_days(date=Date.today)
    week_dates(@week_start || date).map { |d| d.strftime('%a') }
  end
end