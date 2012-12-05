map.resources :week_logs, :only => [:index, :update], 
  :collection => {
    :add_task => :post, 
    :remove_task => :post, 
    :task_search => :post,
    :iter_refresh => :post,
    :load_tables => :post
  }

map.resources :contractor_logs

map.connect 'leaves/save_leaves', :controller => 'leave_logs', :action => 'save_leaves'
