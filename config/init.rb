require 'redmine'
require 'dispatcher'

require File.dirname(__FILE__) + '/install_assets'
Dir[File.dirname(__FILE__) + '/../app/helpers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../app/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../lib/time_logging/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../app/controllers/*.rb'].each {|file| require file }
ActionController::Base.prepend_view_path File.dirname(__FILE__) + "/../app/views"

$redis = Redis.new

ActionView::Base.send(:include, WeekLogsHelper)
Issue.send(:include, TimeLogging::IssuePatch)
TimeEntry.send(:include,TimeEntryExtn)

Redmine::Plugin.register :time_logging do
  name 'Weekly time logging plugin'
  author 'Exist DEN Team'
  description 'Patch for new weekly time logging features'
  version '1.0.0'

  menu :top_menu,
       :my_time_logs,
       { :controller => 'week_logs', :action => :index },
       :caption => 'My time logs',
       :after   => :my_page,
       :if => Proc.new { User.current.logged? }
end
