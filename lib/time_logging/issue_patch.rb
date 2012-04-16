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

      def loggable?(user)
        member = project.members.select {|m| m.user.id == user.id}.first
        return false if !member
        if project.accounting
          project.accounting.name=="Billable" ? issue_is_billable = true : issue_is_billable = false
        else
          issue_is_billable = false
        end
        if(project.project_type.scan(/^(Admin)/).flatten.present?)
          true
        elsif(issue_is_billable && member.billable)
          false
        else
          true
        end
      end
    end
  end
end
