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
end
