class << ActionController::Routing::Routes
  def load_time_logging_routes
    original_routes = routes.dup
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
    @routes += original_routes
  end
end
