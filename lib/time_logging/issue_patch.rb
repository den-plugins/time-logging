require_dependency 'issue'
require 'json'

module TimeLogging
  module IssuePatch
    def self.included(base) # :nodoc:
      base.send :include, InstanceMethods

      base.class_eval do
        after_update :update_cache
        after_create :update_cache
        before_destroy :destroy_cache_instance
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
        x = project.project_type.to_s.downcase[/admin|na/]
        x ? x : false
      end
      
      def assigned_to_all?
        tracker = self.tracker.name.downcase
        if tracker['task'] || tracker['support']
          assign = self.custom_values.detect {|x| x.customized_type=="Issue" and x.custom_field.name.downcase["assign"]} 
          if assign
            assign.value.to_i == 1 ? true : false
          else
            false
          end
        else
          false
        end
      end
      
      def support_task?
        tracker = self.tracker.name.downcase
        (tracker['task'] || tracker['support']) ? true : false
      end

      def update_cache
        proj_cache = $redis.get "project_issue_ids_#{User.current.id}"
        proj_cache ? proj_cache = JSON(proj_cache) : proj_cache = []
        non_proj_cache = $redis.get "non_project_issue_ids_#{User.current.id}"
        non_proj_cache ? non_proj_cache = JSON(non_proj_cache) : non_proj_cache = [] 
        del_flag = false
        if project.members.find_by_user_id User.current.id
          if (User.current == assigned_to or (support_task? and assigned_to_all?)) and !admin? 
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

      def destroy_cache_instance
        $redis.keys.each do |key|
          array = JSON($redis.get(key))
          duplicate = array.dup
          array.each do |arr_key|
            begin
              Issue.find(arr_key)
              duplicate.delete(arr_key) if arr_key == self.id
            rescue ActiveRecord::RecordNotFound
              puts duplicate.inspect
              duplicate.delete arr_key
              puts duplicate.inspect
            end
          end
          $redis.set key, JSON(duplicate)
        end
      end

    end
  end
end
