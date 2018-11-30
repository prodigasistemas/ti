#!/usr/bin/env puma

directory 'APP_PATH/APP_NAME/current'
rackup "APP_PATH/APP_NAME/current/config.ru"
environment 'production'

tag ''

pidfile "APP_PATH/APP_NAME/shared/tmp/pids/puma.pid"
state_path "APP_PATH/APP_NAME/shared/tmp/pids/puma.state"
stdout_redirect 'APP_PATH/APP_NAME/shared/log/puma_access.log', 'APP_PATH/APP_NAME/shared/log/puma_error.log', true

threads 0,16

bind 'unix://APP_PATH/APP_NAME/shared/tmp/sockets/puma.sock'

workers 0

prune_bundler

on_restart do
  puts 'Refreshing Gemfile'
  ENV["BUNDLE_GEMFILE"] = ""
end
