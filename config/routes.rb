class << ActionController::Routing::Routes
  def load_time_logging_routes
    draw do |map|
      map.resources :week_logs, :only => [:index, :update],
        :collection => {
          :add_task => :post,
          :remove_task => :post,
          :task_search => :post,
          :iter_refresh => :post,
          :load_tables => :post
        }
    end
    additional_routes = @routes.dup
    reload!
    @routes += additional_routes
  end
  ActionController::Routing::Routes.load_time_logging_routes
end
