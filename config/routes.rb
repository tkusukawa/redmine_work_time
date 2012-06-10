RedmineApp::Application.routes.draw do
  match 'work_time/:action', :to => 'work_time#index'
  match 'work_time/:action/:id', :to => 'work_time#show'
end
