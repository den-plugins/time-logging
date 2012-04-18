require_dependency 'issue'

module TimeLogging
  module IssuePatch
    def self.included(base) # :nodoc:
      base.send :include, InstanceMethods

      base.class_eval do
        after_save :update_cache
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

      def update_cache
        proj_cache = Rails.cache.read :project_issue_ids
        proj_cache ? proj_cache = proj_cache.dup : proj_cache = [] 
        non_proj_cache = Rails.cache.read :non_project_issue_ids
        non_proj_cache ? non_proj_cache = non_proj_cache.dup : non_proj_cache = [] 
        if User.current == assigned_to
          if project.project_type.to_s !~ /admin/i && project.name !~ /admin/i
            proj_cache << id
          else
            non_proj_cach << id
          end
        end
        Rails.cache.write :project_issue_ids, proj_cache.uniq
        Rails.cache.write :non_project_issue_ids, non_proj_cache.uniq
      end
    end
  end
end
