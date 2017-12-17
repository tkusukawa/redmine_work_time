WorkTime is a Redmine plugin to edit spent time by each user.

### Installation notes ###

0. Setup Redmine
1. Download redmine_work_time-*.zip from https://github.com/tkusukawa/redmine_work_time/releases
2. Expand the plugin into the plugins directory
3. Migrate plugin:  
  $ RAILS_ENV=production bundle exec rake redmine:plugins:migrate
4. Restart Redmine
5. Enable the module on the project setting page.
6. Check the permissions on the Roles and permissions(Administration)

### Links ###

* http://www.redmine.org/plugins/redmine_work_time
* https://github.com/tkusukawa/redmine_work_time
* http://www.r-labs.org/projects/worktime/
