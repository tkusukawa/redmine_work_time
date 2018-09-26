require_dependency 'projects_helper'

module WorkTimeProjectsHelperPatch
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super
      action = {:name => 'work_time',
                :controller => 'work_time',
                :action => :show,
                :partial => 'settings/work_time_project_settings', :label => :work_time}
      tabs << action if User.current.allowed_to?(:edit_work_time_total, @project)
      tabs
    end
  end
end

ProjectsHelper.prepend WorkTimeProjectsHelperPatch::ProjectsHelperPatch
