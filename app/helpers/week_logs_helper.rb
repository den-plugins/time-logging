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
    direction = column == params[type] && params["#{type}_dir"] == "asc" ? "desc" : "asc"
    link_to title, {:"#{type}"=> column, :"#{type}_dir" => direction}, {:class=>"#{type} #{direction}"}
  end
end
