require 'redmine'
require File.dirname(__FILE__) + '/app/helpers/save_week_logs'
require File.dirname(__FILE__) + '/app/models/time_entry_extn'
require File.dirname(__FILE__) + '/app/helpers/extend_account_controller'

Dispatcher.to_prepare do
  Issue.send(:include, TimeLogging::IssuePatch)
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
