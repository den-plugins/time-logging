map.resources :week_logs, :only => [:index, :update], 
  :collection => {
    :add_task => :post, 
    :remove_task => :post, 
    :task_search => :post,
    :iter_refresh => :post,
    :load_tables => :post
  }
