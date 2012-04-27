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
        project.project_type.to_s.downcase['admin']
      end

      def update_cache
        proj_cache = $redis.get "project_issue_ids_#{User.current.id}"
        proj_cache ? proj_cache = JSON(proj_cache) : proj_cache = []
        non_proj_cache = $redis.get "non_project_issue_ids_#{User.current.id}"
        non_proj_cache ? non_proj_cache = JSON(non_proj_cache) : non_proj_cache = [] 
        del_flag = false
        if project.members.find_by_user_id User.current.id
          if User.current == assigned_to && !admin? 
            proj_cache << id
          elsif admin?
            non_proj_cache << id
          else
            del_flag = true
          end
        else
          del_flag = true
        end
        if del_flag
          proj_cache.delete id
          non_proj_cache.delete id
        end
        $redis.set "project_issue_ids_#{User.current.id}", JSON(proj_cache)
        $redis.set "non_project_issue_ids_#{User.current.id}", JSON(non_proj_cache)
      end
    end
  end
end
