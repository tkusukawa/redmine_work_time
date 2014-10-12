WorkTime is a plugin of Redmine to view and update Spent time by each user.

### Installation notes ###

0. Setup Redmine
1. Download redmine_work_time-*.zip from https://bitbucket.org/tkusukawa/redmine_work_time/downloads
2. Expand the plugin into the plugins directory
3. Migrate plugin: rake redmine:plugins:migrate RAILS_ENV=production
4. Restart Redmine
5. Enable the module on the project setting page.
6. Check the permissions on the Roles and permissions(Administration)

### Links ###

* http://www.redmine.org/plugins/redmine_work_time
* https://bitbucket.org/tkusukawa/redmine_work_time
* http://www.r-labs.org/projects/worktime/