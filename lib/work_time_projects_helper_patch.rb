require_dependency 'projects_helper'

module WorkTimeProjectsHelperPatch
  def self.included base # :nodoc:
    base.send :include, ProjectsHelperMethodsWorkTime
    base.class_eval do
      alias_method_chain :project_settings_tabs, :work_time
    end
  end
end

module ProjectsHelperMethodsWorkTime
  def project_settings_tabs_with_work_time
    tabs = project_settings_tabs_without_work_time
    action = {:name => 'work_time',
      :controller => 'work_time',
      :action => :show, 
      :partial => 'settings/work_time_project_settings', :label => :work_time}
    tabs << action if User.current.allowed_to?(:edit_work_time_total, @project)
    tabs
  end
end
