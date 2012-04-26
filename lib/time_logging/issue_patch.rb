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
      require 'json'
      def admin?
        project.name.downcase.include? 'admin'
      end

      def update_cache
        red = Redis.new
        proj_cache = red.get "project_issue_ids_#{User.current.id}"
        proj_cache ? proj_cache = JSON(proj_cache) : proj_cache = []
        non_proj_cache = red.get "non_project_issue_ids_#{User.current.id}"
        non_proj_cache ? non_proj_cache = JSON(non_proj_cache) : non_proj_cache = [] 
        if User.current == assigned_to
          if project.project_type.to_s !~ /admin/i && project.name !~ /admin/i
            proj_cache << id
          else
            non_proj_cach << id
          end
        else
          proj_cache.delete id
          non_proj_cache.delete id
        end
        red.set "project_issue_ids_#{User.current.id}", JSON(proj_cache)
        red.set "non_project_issue_ids_#{User.current.id}", JSON(non_proj_cache)
      end
    end
  end
end
