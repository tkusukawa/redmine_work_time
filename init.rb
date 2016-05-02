require 'redmine'

Redmine::Plugin.register :redmine_work_time do
  name 'Redmine Work Time plugin'
  author 'Tomohisa Kusukawa'
  description 'A plugin to view and update TimeEntry by each user'
  version '0.3.2'
  url 'http://www.r-labs.org/projects/worktime'
  author_url 'http://about.me/tkusukawa'
  
  project_module :work_time do
    permission :view_work_time_tab, {:work_time =>
            [:show,:member_monthly_data,
             :total,:total_data,:edit_relay,:relay_total,:relay_total_data,
             :project_settings,
            ]}
    permission :view_work_time_other_member, {}
    permission :edit_work_time_total, {}
    permission :edit_work_time_other_member, {}
  end

  menu :account_menu, :work_time,
    {:controller => 'work_time', :action => 'index'},
    :before => :my_account,
    :caption => :work_time,
    :if => Proc.new{User.current.logged? && Setting.plugin_redmine_work_time['show_account_menu']}

  menu :project_menu, :work_time,
    {:controller => 'work_time', :action => 'show'}, :caption => :work_time,
    :after => :gantt

  settings :default => {'account_start_days' => {}, 'show_account_menu' => 'true'},
           :partial => 'settings/work_time_settings'

  Rails.configuration.to_prepare do
    require_dependency 'projects_helper'
    unless ProjectsHelper.included_modules.include? WorkTimeProjectsHelperPatch
      ProjectsHelper.send(:include, WorkTimeProjectsHelperPatch)
    end
  end
end
