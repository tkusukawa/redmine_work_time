require 'redmine'

Redmine::Plugin.register :redmine_work_time do
  name 'Redmine Work Time plugin'
  author 'Tomohisa Kusukawa'
  description 'A plugin to view and update TimeEntry by each user'
  version '0.2.3'
  
  project_module :work_time do
    permission :view_work_time_tab, {:work_time =>
            [:show,:total,:total_data,:edit_relay,:relay_total,
            :relay_total_data,:popup_select_ticket,:ajax_select_ticket,
            :popup_select_tickets,:ajax_select_tickets,:ajax_insert_daily,
            :ajax_memo_edit,:ajax_relay_table]}
    permission :view_work_time_other_member, {}
    permission :edit_work_time_total, {}
  end

  menu :account_menu, :work_time,
    {:controller => 'work_time', :action => 'index'}, :caption => :work_time
  menu :project_menu, :work_time,
    {:controller => 'work_time', :action => 'show'}, :caption => :work_time
end
