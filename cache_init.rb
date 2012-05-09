require "rubygems"
require "redis"
x = Redis.new
x.keys.each {|z| x.del z}
