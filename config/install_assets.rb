root     = RAILS_ROOT
curr_dir = File.dirname(__FILE__)

js_dest    = %Q{#{root}/public/javascripts/time_logging}
js_orig    = %Q{#{curr_dir}/../assets/javascripts/}
style_dest = %Q{#{root}/public/stylesheets/time_logging}
style_orig = %Q{#{curr_dir}/../assets/stylesheets/}

#clean all installed assets
FileUtils.rm_r js_dest, :force => true
FileUtils.rm_r style_dest, :force => true

#copy all js assets to <app>/public/javascripts/time_logging
FileUtils.cp_r js_orig, js_dest

#copy all stylesheet assets to <app>/public/stylesheets/time_logging
FileUtils.cp_r style_orig, style_dest
