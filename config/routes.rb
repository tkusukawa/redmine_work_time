ActionController::Routing::Routes.draw do |map|
  map.connect 'work_time', :controller => 'work_time', :action => :index
  map.connect 'work_time/:action/:id', :controller => 'work_time', :action => :show
  map.connect 'work_time', :controller => 'work_time', :action => :total
  map.connect 'work_time', :controller => 'work_time', :action => :edit_relay
  map.connect 'work_time', :controller => 'work_time', :action => :relay_total
  map.connect 'work_time', :controller => 'work_time', :action => :relay_total2
  map.connect 'work_time', :controller => 'work_time', :action => :popup_select_ticket
  map.connect 'work_time', :controller => 'work_time', :action => :popup_select_tickets
  map.connect 'work_time', :controller => 'work_time', :action => :popup_update_done_ratio
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_select_ticket
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_select_tickets
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_update_done_ratio
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_insert_daily
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_memo_edit
  map.connect 'work_time', :controller => 'work_time', :action => :ajax_relay_table
end