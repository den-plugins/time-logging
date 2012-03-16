module WeekLogsHelper
  def week_dates(date=Date.today)
    date = @week_start || date
    # Monday to Saturday + Sunday of the previous week
    [*date.beginning_of_week..(date.end_of_week - 1.day)].push(date.beginning_of_week - 1)
  end

  def week_days
    %w[mon tue wed thu fri sat sun]
  end
end