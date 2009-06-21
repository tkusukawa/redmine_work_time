Redmineプラグイン(WorkTime) 作成覚書

cd $RAILS_ROOT

***プラグインの雛形生成***
# ruby script/generate redmine_plugin work_time

***バージョン管理に登録***
# cd vendor/plugins/redmine_work_time
# hg init
# hg commit -A

***init.rbの編集***
# vi init.rb

# cat init.rb
require 'redmine'

Redmine::Plugin.register :redmine_work_time do
  name 'Redmine Work Time plugin'
  author 'Tomohisa Kusukawa'
  description 'A plugin to view and update TimeEntry by each user'
  version '0.0.1'

  project_module :work_time do
    permission :view_work_time_tab, {:work_time => [:show]}, :public => true
  end

  menu :project_menu, :work_time, {:controller => 'work_time', :action => 'show'}, :caption => :work_time
end

*** モデル(DBテーブル)の作成 ***

# ruby script/generate redmine_plugin_model work_time user_issue_month uid:integer issue:integer month:string odr:integer
      exists  app/models/
      create  test/unit/
      create  test/fixtures/
      create  app/models/user_issue_month.rb
      create  test/unit/user_issue_month_test.rb
      create  test/fixtures/user_issue_months.yml
      exists  db/migrate
      create  db/migrate/20090104004624_create_user_issue_months.rb
# mv db/migrate/20090104004624_create_user_issue_months.rb db/migrate/001_create_user_issue_months.rb

# ruby script/generate redmine_plugin_model work_time wt_member_order user_id:integer position:integer
      exists  app/models/
      exists  test/unit/
      exists  test/fixtures/
      create  app/models/wt_member_order.rb
      create  test/unit/wt_member_order_test.rb
      create  test/fixtures/wt_member_orders.yml
      exists  db/migrate
      create  db/migrate/20090131105945_create_wt_member_orders.rb
# mv db/migrate/20090131105945_create_wt_member_orders.rb db/migrate/002_create_wt_member_orders.rb

# ruby script/generate redmine_plugin_model work_time wt_ticket_relay issue_id:integer position:integer parent:integer
      exists  app/models/
      exists  test/unit/
      exists  test/fixtures/
      create  app/models/wt_ticket_relay.rb
      create  test/unit/wt_ticket_relay_test.rb
      create  test/fixtures/wt_ticket_relays.yml
      exists  db/migrate
      create  db/migrate/20090131110021_create_wt_ticket_relays.rb
# mv db/migrate/20090131110021_create_wt_ticket_relays.rb db/migrate/003_create_wt_ticket_relays.rb

# vi db/migrate/004_add_prj_to_mem_odr.rb

# ruby script/generate redmine_plugin_model work_time wt_daily_memo day:date user_id:integer created_on:timestamp updated_on:timestamp description:text
      exists  app/models/
      exists  test/unit/
      exists  test/fixtures/
      create  app/models/wt_daily_memo.rb
      create  test/unit/wt_daily_memo_test.rb
      create  test/fixtures/wt_daily_memos.yml
      exists  db/migrate
      create  db/migrate/20090221151021_create_wt_daily_memos.rb
# mv db/migrate/20090221151021_create_wt_daily_memos.rb db/migrate/005_create_wt_daily_memos.rb

# rake db:migrate_plugins RAILS_ENV=production

*** コントローラの作成 ***

# ruby script/generate redmine_plugin_controller work_time work_time show
      exists  app/controllers/
      exists  app/helpers/
      create  app/views/work_time
      create  test/functional/
      create  app/controllers/work_time_controller.rb
      create  test/functional/work_time_controller_test.rb
      create  app/helpers/work_time_helper.rb
      create  app/views/work_time/show.html.erb

# cd $RAILS_ROOT/vendor/plugins/redmine_work_time/app/controllers/
# vi work_time_controller.rb

*** ビューの編集 ***

# cd $RAILS_ROOT/vendor/plugins/redmine_work_time/app/view/work_time/
# vi show.html.erb

######################################################################### version 0.0.33
ユーザーの月毎表示におけるチケットトータル工数の表示を左側に変更

######################################################################### version 0.0.34
ユーザ毎の工数表示をプロジェクト毎にまとめて表示するように変更
# cd $RAILS_ROOT
# ruby script/generate redmine_plugin_model work_time wt_project_orders prj:integer uid:integer dsp_prj:integer dsp_pos:integer
      exists  app/models/
      exists  test/unit/
      exists  test/fixtures/
      create  app/models/wt_project_orders.rb
      create  test/unit/wt_project_orders_test.rb
      create  test/fixtures/wt_project_orders.yml
      exists  db/migrate
      create  db/migrate/20090531095136_create_wt_project_orders.rb
# cd vendor/plugins/redmine_work_time/db/migrate/
# mv 20090531095136_create_wt_project_orders.rb 006_create_wt_project_orders.rb
# cd $RAILS_ROOT
# rake db:migrate_plugins RAILS_ENV=production

