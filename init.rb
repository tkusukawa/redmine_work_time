require 'redmine'

Redmine::Plugin.register :redmine_work_time do
  name 'Redmine Work Time plugin'
  author 'Tomohisa Kusukawa'
  description 'A plugin to view and update TimeEntry by each user'
  version '0.0.40'
  
  project_module :work_time do
    permission :view_work_time_tab, {:work_time =>
            [:show,:total,:popup_select_ticket,:ajax_select_ticket,:ajax_insert_daily,:ajax_memo_edit]}
    permission :edit_work_time_total, {}
    permission :view_work_time_other_member, {}
  end

  menu :project_menu, :work_time, {:controller => 'work_time', :action => 'show'}, :caption => :work_time
end
