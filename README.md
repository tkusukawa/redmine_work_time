WorkTime is a Redmine plugin to edit spent time by each user.

### Installation notes ###

* cd {RAILS_ROOT}/plugins
* git clone https://github.com/tkusukawa/redmine_work_time.git
* cd ../
* bundle exec rake redmine:plugins:migrate RAILS_ENV=production
* Restart Redmine
* Enable the module on the project setting page.
* Check the permissions on the Roles and permissions(Administration)

### Links ###

* http://www.redmine.org/plugins/redmine_work_time
* https://github.com/tkusukawa/redmine_work_time
* http://www.r-labs.org/projects/worktime/
