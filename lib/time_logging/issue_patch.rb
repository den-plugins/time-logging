require_dependency 'issue'

module TimeLogging
  module IssuePatch
    def self.included(base) # :nodoc:
      base.send :include, InstanceMethods

      base.class_eval do
        named_scope :assigned_to, lambda { |user|
            user ||= User.current
            { :conditions => { :assigned_to_id => user.id } }
          }
        named_scope :in_projects, lambda { |*projects|
            { :conditions => { :project_id => (projects || []).flatten.map(&:id) } }
          }
      end
    end

    module InstanceMethods
      def admin?
        project.name.downcase.include? 'admin'
      end
    end
  end
end