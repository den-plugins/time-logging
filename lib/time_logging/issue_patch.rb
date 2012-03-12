require_dependency 'issue'

module TimeLogging
  module IssuePatch
    def self.included(base) # :nodoc:
      base.class_eval do
        named_scope :assigned_and_loggable_to, lambda { |user|
            pids = user.memberships.select {|m| m.role.allowed_to?(:log_time)}.collect(&:project_id)
            { :conditions => {
                :assigned_to_id => user.id,
                :project_id => pids } }
          }
      end
    end
  end
end