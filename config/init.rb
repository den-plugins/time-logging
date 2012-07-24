require 'redmine'
require 'dispatcher'

Dir[File.dirname(__FILE__) + '/../app/controllers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../app/helpers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../app/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/../lib/time_logging/*.rb'].each {|file| require file }

$redis = Redis.new

Dispatcher.to_prepare do
  Issue.send(:include, TimeLogging::IssuePatch)
  TimeEntry.send(:include,TimeEntryExtn)
end

Redmine::Plugin.register :time_logging do
  name 'Weekly time logging plugin'
  author 'Exist DEN Team'
  description 'Patch for new weekly time logging features'
  version '0.0.1'

  menu :top_menu,
       :my_time_logs,
       { :controller => 'week_logs', :action => :index },
       :caption => 'My time logs',
       :after   => :my_page,
       :if => Proc.new { User.current.logged? }
end
