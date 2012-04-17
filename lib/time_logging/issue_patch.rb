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

      def update_session_params(proj, non_proj)
       if User.current == assigned_to
         if project.project_type.to_s !~ /admin/i && project.name !~ /admin/i
           proj.push(id).uniq!
         else
           non_proj.push(id).uniq!
         end
       end
       [proj, non_proj]
      end
    end
  end
end
