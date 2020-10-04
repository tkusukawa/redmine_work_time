class WorkTimeController < ApplicationController
  unloadable
  #  before_filter :find_project, :authorize
  accept_api_auth :relay_total

  helper :custom_fields
  include CustomFieldsHelper

  NO_ORDER = -1

  def index
    @message = ""
    require_login || return
    @project = nil
    prepare_values
    ticket_pos
    prj_pos
    ticket_del
    hour_update
    make_pack
    update_daily_memo(params[:memo]) if params.key?(:memo)
    set_holiday
    @custom_fields = TimeEntryCustomField.all
    @link_params.merge!(:action=>"index")
    if !params.key?(:user) then
      redirect_to @link_params
    else
      render "show"
    end
  end

  def show
    @message = ""
    require_login || return
    find_project
    authorize
    prepare_values
    if @this_user.nil? || !@this_user.allowed_to?(:view_work_time_tab, @project)
      @link_params.merge!(:action=>"relay_total")
      redirect_to @link_params
      return
    end
    ticket_pos
    prj_pos
    ticket_del
    hour_update
    make_pack
    member_add_del_check
    update_daily_memo(params[:memo]) if params.key?(:memo)
    set_holiday
    @custom_fields = TimeEntryCustomField.all
    @link_params.merge!(:action=>"show")
    if !params.key?(:user) then
      redirect_to @link_params
    end
  end

  def member_monthly_data
    require_login || return
    if params.key?(:id) then
      find_project
    end
    prepare_values
    make_pack

    csv_data = %Q|"user","date","project","ticket","spent time"\n|

    (@first_date..@last_date).each do |date|
      @month_pack[:odr_prjs].each do |prj_pack|
        next if prj_pack[:count_issues] == 0
        prj_pack[:odr_issues].each do |issue_pack|
          next if issue_pack[:count_hours] == 0
          issue = issue_pack[:issue]
          if issue_pack[:total_by_day][date] then
            csv_data << %Q|"#{@this_user}","#{date}","#{issue.project}","##{issue.id} #{issue.subject}",#{issue_pack[:total_by_day][date]}\n|
          end
        end
      end
      if @month_pack[:other_by_day].has_key?(date) then
        csv_data << %Q|"#{@this_user}","#{date}","PRIVATE","PRIVATE",#{@month_pack[:other_by_day][date]}\n|
      end
    end
    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"member_monthly.csv"
  end

  def member_monthly_data_table
    require_login || return
    if params.key?(:id) then
      find_project
    end
    prepare_values
    make_pack

    csv_data = %Q|""|
    (@first_date..@last_date).each do |date|
      csv_data << %Q|,"#{date}"|
    end
    csv_data << "\n"
    
    @month_pack[:odr_prjs].each do |prj_pack|
      next if prj_pack[:count_issues] == 0
      prj_pack[:odr_issues].each do |issue_pack|
        next if issue_pack[:count_hours] == 0
        issue = issue_pack[:issue]
        
        csv_data << %Q|"##{issue.id} #{issue.subject}"|
        
        (@first_date..@last_date).each do |date|
          if issue_pack[:total_by_day].has_key?(date) then
            csv_data << %Q|,"#{issue_pack[:total_by_day][date]}"|
          else
            csv_data << %Q|,""|
          end
        end
        
        csv_data << "\n"
      end
    end

    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"member_monthly_table.csv"
  end

  def total
    @message = ""
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total
    @link_params.merge!(:action=>"total")
  end

  def total_data
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total
    
    csv_data = %Q|"user","relayed project","relayed ticket","project","ticket","spent time"\n|
    #-------------------------------------- メンバーのループ
    @members.each do |mem_info|
      user = mem_info[1]

      #-------------------------------------- プロジェクトのループ
      prjs = WtProjectOrders.where("uid=-1").
          order("dsp_pos").
          all
      prjs.each do |po|
        dsp_prj = po.dsp_prj
        dsp_pos = po.dsp_pos
        next unless @prj_cost.key?(dsp_prj) # 値の無いプロジェクトはパス
        next unless @prj_cost[dsp_prj].key?(-1) # 値の無いプロジェクトはパス
        next if @prj_cost[dsp_prj][-1] == 0 # 値の無いプロジェクトはスパ
        prj =Project.find_by_id(dsp_prj)
        
        #-------------------------------------- チケットのループ
        tickets = WtTicketRelay.order("position").all
        tickets.each do |tic|
          issue_id = tic.issue_id
          next unless @issue_cost.key?(issue_id) # 値の無いチケットはパス
          next unless @issue_cost[issue_id].key?(-1) # 値の無いチケットはパス
          next if @issue_cost[issue_id][-1] == 0 # 値の無いチケットはパス
          next unless @issue_cost[issue_id].key?(user.id) # 値の無いチケットはパス
          next if @issue_cost[issue_id][user.id] == 0 # 値の無いチケットはパス

          issue = Issue.find_by_id(issue_id)
          next if issue.nil? # チケットが削除されていたらパス
          next if issue.project_id != dsp_prj # このプロジェクトに表示するチケットでない場合はパス

          parent_issue = Issue.find_by_id(@issue_parent[issue_id])
          next if parent_issue.nil? # チケットが削除されていたらパス

          csv_data << %Q|"#{user}","#{parent_issue.project}","##{parent_issue.id} #{parent_issue.subject}",|
          csv_data << %Q|"#{prj}","##{issue.id} #{issue.subject}",#{@issue_cost[issue_id][user.id]}\n|
        end
      end
      if @issue_cost.has_key?(-1) && @issue_cost[-1].has_key?(user.id) then
        csv_data << %Q|"#{user}","private","private","private","private",#{@issue_cost[-1][user.id]}\n|
      end
    end
    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"monthly_report_raw.csv"
  end

  def total_data_with_act
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total

    csv_data = %Q|"user","relayed project","relayed ticket","project","ticket","activity","spent time"\n|
    @issue_act_cost.each do |issue_id, user_act_cost|
      if issue_id >0
        issue = Issue.find_by_id(issue_id)
        next if issue.nil? # チケットが削除されていたらパス

        parent_issue = Issue.find_by_id(@issue_parent[issue_id])
        next if parent_issue.nil? # チケットが削除されていたらパス

        prj = issue.project

        user_act_cost.each do |user_id, act_cost|
          user = User.find_by_id(user_id)
          act_cost.each do |act_id, cost|
            act = TimeEntryActivity.find_by_id(act_id)
            unless act.nil?
              csv_data << %Q|"#{user}","#{parent_issue.project}","##{parent_issue.id} #{parent_issue.subject}",|
              csv_data << %Q|"#{prj}","##{issue.id} #{issue.subject}","#{act.name}",|
              csv_data << %Q|#{cost}\n|
            else # can not find activity
              csv_data << %Q|"#{user}","#{parent_issue.project}","##{parent_issue.id} #{parent_issue.subject}",|
              csv_data << %Q|"#{prj}","##{issue.id} #{issue.subject}","nil",|
              csv_data << %Q|#{cost}\n|
            end
          end
        end
      else # 表示権限の無い工数があった場合
        user_act_cost.each do |user_id, act_cost|
          user = User.find_by_id(user_id)
          act_cost.each do |act_id, cost|
            csv_data << %Q|"#{user}","private","private","private","private","private",|
            csv_data << %Q|#{cost}\n|
          end
        end
      end
    end
    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"monthly_report_raw_with_act.csv"
  end

  def edit_relay
    @message = ""
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total
    @link_params.merge!(:action=>"edit_relay")
  end

  def relay_total
    @message = ""
    find_project || return
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total
    respond_to do |format|
	format.html {
	    @link_params.merge!(:action=>"relay_total")
	}
	format.api {}
    end
  end

  def relay_total_data
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total
    
    csv_data = %Q|"user","project","ticket","spent time"\n|
    #-------------------------------------- メンバーのループ
    @members.each do |mem_info|
      user = mem_info[1]

      #-------------------------------------- プロジェクトのループ
      prjs = WtProjectOrders.where("uid=-1").
          order("dsp_pos").
          all
      prjs.each do |po|
        dsp_prj = po.dsp_prj
        dsp_pos = po.dsp_pos
        next unless @r_prj_cost.key?(dsp_prj) # 値の無いプロジェクトはパス
        next unless @r_prj_cost[dsp_prj].key?(-1) # 値の無いプロジェクトはパス
        next if @r_prj_cost[dsp_prj][-1] == 0 # 値の無いプロジェクトはスパ
        prj =Project.find_by_id(dsp_prj)
        
        #-------------------------------------- チケットのループ
        tickets = WtTicketRelay.order("position").all
        tickets.each do |tic|
          issue_id = tic.issue_id
          next unless @r_issue_cost.key?(issue_id) # 値の無いチケットはパス
          next unless @r_issue_cost[issue_id].key?(-1) # 値の無いチケットはパス
          next if @r_issue_cost[issue_id][-1] == 0 # 値の無いチケットはパス
          next unless @r_issue_cost[issue_id].key?(user.id) # 値の無いチケットはパス
          next if @r_issue_cost[issue_id][user.id] == 0 # 値の無いチケットはパス

          issue = Issue.find_by_id(issue_id)
          next if issue.nil? # チケットが削除されていたらパス
          next if issue.project_id != dsp_prj # このプロジェクトに表示するチケットでない場合はパス

          csv_data << %Q|"#{user}","#{prj}","##{issue.id} #{issue.subject}",#{@r_issue_cost[issue_id][user.id]}\n|
        end
      end
      if @r_issue_cost.has_key?(-1) && @r_issue_cost[-1].has_key?(user.id) then
        csv_data << %Q|"#{user}","private","private",#{@r_issue_cost[-1][user.id]}\n|
      end
    end
    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"monthly_report.csv"
  end

  def relay_total_data_with_act
    find_project
    authorize
    prepare_values
    change_member_position
    change_ticket_position
    change_project_position
    member_add_del_check
    calc_total

    csv_data = %Q|"user","project","ticket","activity","spent time"\n|
    @r_issue_act_cost.each do |issue_id, user_act_cost|
      if issue_id >0
        issue = Issue.find_by_id(issue_id)
        next if issue.nil?
        prj = issue.project

        user_act_cost.each do |user_id, act_cost|
          user = User.find_by_id(user_id)
          act_cost.each do |act_id, cost|
            act = TimeEntryActivity.find_by_id(act_id)
            unless act.nil?
              csv_data << %Q|"#{user}","#{prj}","##{issue.id} #{issue.subject}",|
              csv_data << %Q|"#{act.name}",#{cost}\n|
            else # can not find activity
              csv_data << %Q|"#{user}","#{prj}","##{issue.id} #{issue.subject}",|
              csv_data << %Q|"nil",#{cost}\n|
            end
          end
        end
      else # 表示権限の無い工数があった場合
        user_act_cost.each do |user_id, act_cost|
          user = User.find_by_id(user_id)
          act_cost.each do |act_id, cost|
            csv_data << %Q|"#{user}","private","private",|
            csv_data << %Q|"private",#{cost}\n|
          end
        end
      end
    end
    send_data Redmine::CodesetUtil.from_utf8(csv_data, l(:general_csv_encoding)), :type=>"text/csv", :filename=>"monthly_report_with_act.csv"
  end

  def ajax_relay
    if !params.key?(:issue_id)
      render :layout=>false, :text=>'ERROR: no issue_id'
      return
    end
    @issue_id = params[:issue_id].to_i

    find_project
    @message = ''
    @parent_disp = ''
    @relay_modified = false

    if params.key?(:parent_id)
      @parent_id = params[:parent_id].to_i
      if @parent_id >= 0
        update_relay @issue_id, @parent_id
      else
        # parent_id == -1 by set_ticket_relay_by_issue_relation
        redmine_parent_id = Issue.find_by_id(@issue_id).parent_id
        if redmine_parent_id && redmine_parent_id >= 1 # has parent
          update_relay @issue_id, redmine_parent_id
        end
      end
    end
    relay = WtTicketRelay.where(["issue_id=:i",{:i=>@issue_id}]).first
    @parent_id = relay.parent

    if @parent_id != 0 && !((parent = Issue.find_by_id(@parent_id)).nil?) then
      @parent_disp = parent.closed? ? '<del>'+parent.to_s+'</del>' : parent.to_s
    end
    render :layout=>false
  end

  def update_relay(issue_id, parent_id)
    if !User.current.allowed_to?(:edit_work_time_total, @project)
      @message ||= ''
      @message += l(:wt_no_permission)
      return
    end

    # loop relay check
    route = ''
    search_id = parent_id
    while search_id != 0 do
      route += "->#{search_id}"
      if search_id == issue_id
        @message ||= ''
        @message += l(:wt_loop_relay)+route
        return
      end
      relay = WtTicketRelay.where(["issue_id=:i",{:i=>search_id}]).first
      break if !relay
      search_id = relay.parent
    end

    relay = WtTicketRelay.where(["issue_id=:i",{:i=>issue_id}]).first
    if relay then
      relay.parent = parent_id
      relay.save
      @relay_modified = true
    else
      @message ||= ''
      @message += "Internal Error: no WtTicketRelay for ##{issue_id}"
    end
  end

  def ajax_relay_input # チケット選択の内容を返すアクション
    @issue_id = params[:issue_id]
    @projects = Project.joins("INNER JOIN wt_project_orders ON wt_project_orders.dsp_prj=projects.id AND wt_project_orders.uid=-1").
        select("projects.*, wt_project_orders.dsp_pos as pos").
        order("pos").
        all
    render(:layout=>false)
  end

  def ajax_relay_input_select # チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    @issue_id = params[:issue_id]
    @issues = Issue.includes(:assigned_to).
        where(["project_id=:p",{:p=>params[:prj]}]).
        order("id DESC").
        all
    render(:layout=>false)
  end

  def ajax_add_tickets_input
    prepare_values
    @select_projects = Project.
        joins("LEFT JOIN wt_project_orders ON wt_project_orders.dsp_prj=projects.id AND wt_project_orders.uid=#{User.current.id}").
        select("projects.*, coalesce(wt_project_orders.dsp_pos,100000) as pos").
        order("pos,name").
        all
    render(:layout=>false)
  end

  def ajax_add_tickets_input_select # 複数チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    prepare_values
    @issues = Issue.
        includes(:assigned_to).
        where(["project_id=:p",{:p=>params[:prj]}]).
        order("id DESC").
        all

    render(:layout=>false)
  end

  def ajax_add_tickets_insert # 日毎工数に挿入するAjaxアクション
    prepare_values

    uid = params[:user]
    @add_issue_id = params[:add_issue]
    @add_count = params[:count]
    if @this_uid==@crnt_uid then
      add_issue = Issue.find_by_id(@add_issue_id)
      @add_issue_children_cnt = Issue.where(["parent_id = ?", add_issue.id.to_s]).count
      if add_issue && add_issue.visible? then
        prj = add_issue.project
        if User.current.allowed_to?(:log_time, prj) then
          if add_issue.closed? then
            @issueHtml = "<del>"+add_issue.to_s+"</del>"
          else
            @issueHtml = add_issue.to_s
          end

          @activities = []
          @activity_default = nil
          prj.activities.each do |act|
            @activities.push([act.name, act.id])
            @activity_default = act.id if act.is_default
          end

          @custom_fields = TimeEntryCustomField.all
          @custom_fields.each do |cf|
            def cf.custom_field
              return self
            end
            def cf.value
              return self.default_value
            end
            def cf.true?
              return self.default_value
            end
          end

          @add_issue = add_issue

          unless UserIssueMonth.exists?(["uid=:u and issue=:i",{:u=>uid, :i=>@add_issue_id}]) then
            # 既存のレコードが存在していなければ追加
            UserIssueMonth.create(:uid=>uid, :issue=>@add_issue_id,
              :odr => UserIssueMonth.where(["uid = ?", uid]).count + 1
            )
          end
        end
      end
    end

    render(:layout=>false)
  end

  def ajax_memo_edit # 日毎のメモ入力フォームを出力するAjaxアクション
    render(:layout=>false)
  end

  def ajax_done_ratio_input # 進捗％更新ポップアップ
    prepare_values
    issue_id = params[:issue_id]
    @issue = Issue.find_by_id(issue_id)
    if @issue.nil? || @issue.closed? || !@issue.visible? then
      @issueHtml = "<del>"+@issue.to_s+"</del>"
    else
      @issueHtml = @issue.to_s
    end
    render(:layout=>false)
  end

  def ajax_done_ratio_update
    prepare_values
    issue_id = params[:issue_id]
    done_ratio = params[:done_ratio]
    @issue = Issue.find_by_id(issue_id)
    if User.current.allowed_to?(:edit_issues, @issue.project) then
      @issue.init_journal(User.current)
      @issue.done_ratio = done_ratio
      @issue.save
    end
    render(:layout=>false)
  end

  def register_project_settings
    @message = ""
    require_login || return
    find_project
    authorize
    @settings = Setting.plugin_redmine_work_time
    @settings = Hash.new unless @settings.is_a?(Hash)
    @settings['account_start_days'] = Hash.new unless @settings['account_start_days'].is_a?(Hash)
    @settings['account_start_days'][@project.id.to_s] = params['account_start_day']
    Setting.plugin_redmine_work_time = @settings
    redirect_to :controller => 'projects',
                :action => 'settings', :id => @project, :tab => 'work_time'
  end

private
  def find_project
    # Redmine Pluginとして必要らしいので@projectを設定
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def prepare_values
    # ************************************* 値の準備
    @crnt_uid = User.current.id
    @this_uid = (params.key?(:user) && User.current.allowed_to?(:view_work_time_other_member, @project)) ? params[:user].to_i : @crnt_uid
    @this_user = User.find_by_id(@this_uid)

    if @project &&
      Setting.plugin_redmine_work_time.is_a?(Hash) &&
      Setting.plugin_redmine_work_time['account_start_days'].is_a?(Hash) &&
      Setting.plugin_redmine_work_time['account_start_days'].has_key?(@project.id.to_s)
        @account_start_day = Setting.plugin_redmine_work_time['account_start_days'][@project.id.to_s].to_i
    else
      @account_start_day = 1
    end

    @today = Date.today
    year = params.key?(:year) ? params[:year].to_i : @today.year
    month = params.key?(:month) ? params[:month].to_i : @today.month
    day = params.key?(:day) ? params[:day].to_i : @today.day
    @this_date = Date.new(year, month, day)
    display_date = @this_date
    display_date <<= 1 if day < @account_start_day
    @display_year = display_date.year
    @display_month = display_date.month

    @last_month = @this_date << 1
    @next_month = @this_date >> 1

    @restrict_project = (params.key?(:prj) && params[:prj].to_i > 0) ? params[:prj].to_i : false

    @first_date = Date.new(@display_year, @display_month, @account_start_day)
    @last_date = (@first_date >> 1) - 1

    @month_names = l(:wt_month_names).split(',')
    @wday_name = l(:wt_week_day_names).split(',')
    @wday_color = ["#faa", "#eee", "#eee", "#eee", "#eee", "#eee", "#aaf"]

    @link_params = {:controller=>"work_time", :id=>@project,
                    :year=>year, :month=>month, :day=>day,
                    :user=>@this_uid, :prj=>@restrict_project}
    @is_registerd_backlog = false
    begin
      Redmine::Plugin.find :redmine_backlogs
      @is_registerd_backlog = true
    rescue Exception => exception
    end
  end

  def ticket_pos
    return if @this_uid != @crnt_uid

    # 重複削除と順序の正規化
    if order_normalization(UserIssueMonth, :issue, :order=>"odr", :conditions=>["uid=:u",{:u=>@this_uid}]) then
      @message ||= ''
      #@message += '<div style="background:#faa;">Warning: normalize UserIssueMonth</div>'
      return
    end

    # 表示チケット順序変更求処理
    if params.key?("ticket_pos") && params[:ticket_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i
      dst = $2.to_i
      src = UserIssueMonth.where(["uid=:u and issue=:i", {:u=>@this_uid,:i=>tid}]).first
      if src then # ポジション変更の場合
        if src.odr > dst then # チケットを前にもっていく場合
          tgts = UserIssueMonth.
              where(["uid=:u and odr>=:o1 and odr<:o2", {:u=>src.uid, :o1=>dst, :o2=>src.odr}]).
              all
          tgts.each do |tgt|
            tgt.odr += 1; tgt.save# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save
        else # チケットを後に持っていく場合
          tgts = UserIssueMonth.
              where(["uid=:u and odr<=:o1 and odr>:o2",{:u=>src.uid, :o1=>dst, :o2=>src.odr}]).
              all
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save
        end
      else
        # 新規のポジションの場合
        tgts = UserIssueMonth.
            where(["uid=:u and odr>=:o1", {:u=>@this_uid, :o1=>dst}]).
            all
        tgts.each do |tgt|
          tgt.odr += 1; tgt.save# 順位をひとつずつ後へ
        end
        UserIssueMonth.create(:uid=>@this_uid, :issue=>tid, :odr=>dst) # 追加
      end
    end
  end

  def prj_pos
    return if @this_uid != @crnt_uid

    # 重複削除と順序の正規化
    if order_normalization(WtProjectOrders, :dsp_prj, :order=>"dsp_pos", :conditions=>["uid=:u",{:u=>@this_uid}]) then
      @message ||= ''
      #@message += '<div style="background:#faa;">Warning: normalize WtProjectOrders</div>'
      return
    end

    # 表示プロジェクト順序変更求処理
    if params.key?("prj_pos") && params[:prj_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i
      dst = $2.to_i
      src = WtProjectOrders.
          where(["uid=:u and dsp_prj=:d",{:u=>@this_uid, :d=>tid}]).
          first

      if src then # ポジション変更の場合
        if src.dsp_pos > dst then # チケットを前にもっていく場合
          tgts = WtProjectOrders.
              where(["uid=:u and dsp_pos>=:o1 and dsp_pos<:o2",{:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}]).
              all
          tgts.each do |tgt|
            tgt.dsp_pos += 1; tgt.save# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save
        else # チケットを後に持っていく場合
          tgts = WtProjectOrders.
              where(["uid=:u and dsp_pos<=:o1 and dsp_pos>:o2",{:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}]).
              all
          tgts.each do |tgt|
            tgt.dsp_pos -= 1; tgt.save# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save
        end
      else
        # 新規のポジションの場合
          tgts = WtProjectOrders.
              where(["uid=:u and dsp_pos>=:o1",{:u=>@this_uid, :o1=>dst}]).
              all
          tgts.each do |tgt|
            tgt.dsp_pos += 1; tgt.save# 順位をひとつずつ後へ
          end
          WtProjectOrders.create(:uid=>@this_uid, :dsp_prj=>tid, :dsp_pos=>dst)
      end
    end
  end

  def ticket_del # チケット削除処理
    if params.key?("ticket_del") then
      if params["ticket_del"]=="closed" then # 終了チケット全削除の場合
          issues = Issue.
              joins("INNER JOIN user_issue_months ON user_issue_months.issue=issues.id").
              where(["user_issue_months.uid=:u",{:u=>@this_uid}]).
              all
          issues.each do |issue|
            if issue.closed? then
              tgt = UserIssueMonth.
                  where(["uid=:u and issue=:i",{:u=>@this_uid,:i=>issue.id}]).first
              tgt.destroy
            end
          end
          return
      end

      # チケット番号指定の削除の場合
      src = UserIssueMonth.
          where(["uid=:u and issue=:i",{:u=>@this_uid,:i=>params["ticket_del"]}]).
          first
      if src && src.uid == @crnt_uid then
          tgts = UserIssueMonth.
              where(["uid=:u and odr>:o",{:u=>src.uid, :o=>src.odr}]).
              all
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save# 当該チケット表示より後ろの全チケットの順位をアップ
          end
          src.destroy# 当該チケット表示を削除
      end
    end
  end

  def hour_update # *********************************** 工数更新要求の処理
    by_other = false
    if @this_uid != @crnt_uid
      if User.current.allowed_to?(:edit_work_time_other_member, @project)
        by_other = true
      else
        return
      end
    end

    # 新規工数の登録
    if params["new_time_entry"] then
      params["new_time_entry"].each do |issue_id, valss|
        issue = Issue.find_by_id(issue_id)
        next if issue.nil? || !issue.visible?
        next if !User.current.allowed_to?(:log_time, issue.project)
        valss.each do |count, vals|
          tm_vals = vals.except "remaining_hours", "status_id"
          if params.has_key?("new_time_entry_#{issue_id}_#{count}")
            params["new_time_entry_#{issue_id}_#{count}"].each do |k, v|
              tm_vals[k] = v
            end
          end
          next if tm_vals["hours"].blank? && vals["remaining_hours"].blank? && vals["status_id"].blank?
          if tm_vals["hours"].present? then
            if !tm_vals[:activity_id] then
              append_error_message_html(@message, 'Error: Issue'+issue_id+': No Activities!')
              next
            end
            if by_other
              append_text = "\n[#{Time.now.localtime.strftime("%Y-%m-%d %H:%M")}] #{User.current.to_s}"
              append_text += " add time entry of ##{issue.id.to_s}: #{tm_vals[:hours].to_f}h"
              update_daily_memo(append_text, true)
            end
            new_entry = TimeEntry.new(:project => issue.project, :issue => issue, :author => User.current, :user => @this_user, :spent_on => @this_date)
            new_entry.safe_attributes = tm_vals
            new_entry.save
            append_error_message_html(@message, hour_update_check_error(new_entry, issue_id))
          end
          if vals["remaining_hours"].present? || vals["status_id"].present? then
            append_error_message_html(@message, issue_update_to_remain_and_more(issue_id, vals))
          end
        end
      end
    end

    # 既存工数の更新
    if params["time_entry"] then
      params["time_entry"].each do |id, vals|
        tm = TimeEntry.find_by_id(id)
        issue_id = tm.issue.id
        tm_vals = vals.except "remaining_hours", "status_id"
        if params.has_key?("time_entry_"+id.to_s)
          params["time_entry_"+id.to_s].each do |k,v|
            tm_vals[k] = v
          end
        end
        if tm_vals["hours"].blank? then
          # 工数指定が空文字の場合は工数項目を削除
          if by_other
            append_text = "\n[#{Time.now.localtime.strftime("%Y-%m-%d %H:%M")}] #{User.current.to_s}"
            append_text += " delete time entry of ##{issue_id.to_s}: -#{tm.hours.to_f}h-"
            update_daily_memo(append_text, true)
          end
          tm.destroy
        else
          if by_other && tm_vals.key?(:hours) && tm.hours.to_f != tm_vals[:hours].to_f
            append_text = "\n[#{Time.now.localtime.strftime("%Y-%m-%d %H:%M")}] #{User.current.to_s}"
            append_text += " update time entry of ##{issue_id.to_s}: -#{tm.hours.to_f}h- #{tm_vals[:hours].to_f}h"
            update_daily_memo(append_text, true)
          end
          tm.safe_attributes = tm_vals
          tm.save
          append_error_message_html(@message, hour_update_check_error(tm, issue_id))
        end
        if vals["remaining_hours"].present? || vals["status_id"].present? then
          append_error_message_html(@message, issue_update_to_remain_and_more(issue_id, vals))
        end
      end
    end
  end

  def issue_update_to_remain_and_more(issue_id, vals)
    issue = Issue.find_by_id(issue_id)
    return 'Error: Issue'+issue_id+': Private!' if issue.nil? || !issue.visible?
    return if vals["remaining_hours"].blank? && vals["status_id"].blank?
    journal = issue.init_journal(User.current)
    # update "0.0" is changed
    vals["remaining_hours"] = 0 if vals["remaining_hours"] == "0.0"
    if vals['status_id'] =~ /^M+(.*)$/
      vals['status_id'] = $1.to_i
    else
      vals.delete 'status_id'
    end
    issue.safe_attributes = vals
    return if !issue.changed?
    issue.save
    hour_update_check_error(issue, issue_id)
  end

  def append_error_message_html(html, msg)
    @message ||= ''
    @message += '<div style="background:#faa;">' + msg + '</div><br>' if !msg.blank?
  end

  def hour_update_check_error(obj, issue_id)
    return "" if obj.errors.empty?
    str = l("field_issue")+"#"+issue_id.to_s+"<br>"
    fm = obj.errors.full_messages
    fm.each do |msg|
        str += msg+"<br>"
    end
    str.html_safe
  end

  def member_add_del_check
    # プロジェクトのメンバーを取得
    mem = Member.where(["project_id=:prj", {:prj=>@project.id}]).all
    mem_by_uid = {}
    mem.each do |m|
      next if m.nil? || m.user.nil? || ! m.user.allowed_to?(:view_work_time_tab, @project)
      mem_by_uid[m.user_id] = m
    end

    # メンバーの順序を取得
    odr = WtMemberOrder.where(["prj_id=:p", {:p=>@project.id}]).order("position").all

    # 当月のユーザ毎の工数入力数を取得
    entry_count = TimeEntry.
        where(["spent_on>=:first_date and spent_on<=:last_date",
               {:first_date=>@first_date, :last_date=>@last_date}]).
        select("user_id, count(hours)as cnt").
        group("user_id").
        all
    cnt_by_uid = {}
    entry_count.each do |ec|
      cnt_by_uid[ec.user_id] = ec.cnt
    end

    @members = []
    pos = 1
    # 順序情報にあってメンバーに無いものをチェック
    odr.each do |o|
      if mem_by_uid.has_key?(o.user_id) then
        user=mem_by_uid[o.user_id].user
        if ! user.nil? then
          # 順位の確認と修正
          if o.position != pos then
            o.position=pos
            o.save
          end
          # 表示メンバーに追加
          if user.active? || cnt_by_uid.has_key?(user.id) then
            @members.push([pos, user])
          end
          pos += 1
          # 順序情報に存在したメンバーを削っていく
          mem_by_uid.delete(o.user_id)
          next
        end
      end
      # メンバーに無い順序情報は削除する
      o.destroy
    end

    # 残ったメンバーを順序情報に加える
    mem_by_uid.each do |k,v|
      user = v.user
      next if user.nil?
      n = WtMemberOrder.new(:user_id=>user.id,
                              :position=>pos,
                              :prj_id=>@project.id)
      n.save
      if user.active? || cnt_by_uid.has_key?(user.id) then
        @members.push([pos, user])
      end
      pos += 1
    end
    
  end

  def update_daily_memo(text, append = false) # 日ごとメモの更新
    year = params[:year] || return
    month = params[:month] || return
    day = params[:day] || return
    user_id = params[:user] || return

    # ユーザと日付で既存のメモを検索
    date = Date.new(year.to_i,month.to_i,day.to_i)
    memo = WtDailyMemo.where(["day=:d and user_id=:u",{:d=>date,:u=>user_id}]).first

    if memo then
      # 既存のメモがあれば
      text = memo.description + text if append
      memo.description = text
      memo.updated_on = Time.now
      memo.save # 更新
    else
      # 既存のメモがなければ新規作成
      now = Time.now
      WtDailyMemo.create(:user_id=>user_id,
                         :day=>date,
                         :created_on=>now,
                         :updated_on=>now,
                         :description=>text)
    end
  end

  ################################ 休日設定
  def set_holiday
    user_id = params["user"] || return
    if set_date = params['set_holiday'] then
      WtHolidays.create(:holiday=>set_date, :created_on=>Time.now, :created_by=>user_id)
    end
    if del_date = params['del_holiday'] then
      holidays = WtHolidays.where(["holiday=:h and deleted_on is null",{:h=>del_date}]).all
      holidays.each do |h|
        h.deleted_on = Time.now
        h.deleted_by = user_id
        h.save
      end
    end
  end

  def change_member_position
    ################################### メンバー順序変更処理
    if params.key?("member_pos") && params[:member_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        uid = $1.to_i
        dst = $2.to_i
        mem = WtMemberOrder.where(["prj_id=:p and user_id=:u",{:p=>@project.id, :u=>uid}]).first
        if mem then
          if mem.position > dst then # メンバーを前に持っていく場合
            tgts = WtMemberOrder.
                where(["prj_id=:p and position>=:p1 and position<:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}]).
                all
            tgts.each do |mv|
              mv.position+=1; mv.save # 順位を一つずつ後へ
            end
            mem.position=dst; mem.save
          end
          if mem.position < dst then # メンバーを後に持っていく場合
            tgts = WtMemberOrder.
                where(["prj_id=:p and position<=:p1 and position>:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}]).
                all
            tgts.each do |mv|
              mv.position-=1; mv.save # 順位を一つずつ前へ
            end
            mem.position=dst; mem.save
          end
        end
      else
        @message ||= ''
        @message += '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
        return
      end
    end
  end

  def change_ticket_position
    # 重複削除と順序の正規化
    if order_normalization(WtTicketRelay, :issue_id, :order=>"position") then
      @message ||= ''
      #@message += '<div style="background:#faa;">Warning: normalize WtTicketRelay</div>'
      return
    end

    ################################### チケット表示順序変更処理
    if params.key?("ticket_pos") && params[:ticket_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        issue_id = $1.to_i
        dst = $2.to_i
        relay = WtTicketRelay.where(["issue_id=:i",{:i=>issue_id}]).first
        if relay then
          if relay.position > dst then # 前に持っていく場合
            tgts = WtTicketRelay.
                where(["position>=:p1 and position<:p2",{:p1=>dst, :p2=>relay.position}]).
                all
            tgts.each do |mv|
              mv.position+=1; mv.save # 順位を一つずつ後へ
            end
            relay.position=dst; relay.save
          end
          if relay.position < dst then # 後に持っていく場合
            tgts = WtTicketRelay.
                where(["position<=:p1 and position>:p2",{:p1=>dst, :p2=>relay.position}]).
                all
            tgts.each do |mv|
              mv.position-=1; mv.save # 順位を一つずつ前へ
            end
            relay.position=dst; relay.save
          end
        end
      else
        @message ||= ''
        @message += '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
        return
      end
    end
  end


  def change_project_position
    # 重複削除と順序の正規化
    if order_normalization(WtProjectOrders, :dsp_prj, :order=>"dsp_pos", :conditions=>"uid=-1") then
      @message ||= ''
      #@message += '<div style="background:#faa;">Warning: normalize WtProjectOrders</div>'
      return
    end

    ################################### プロジェクト表示順序変更処理
    return if !params.key?("prj_pos") # 位置変更パラメータが無ければパス
    return if !(params[:prj_pos]=~/^(.*)_(.*)$/) # パラメータの形式が正しくなければパス
    dsp_prj = $1.to_i
    dst = $2.to_i

    if !User.current.allowed_to?(:edit_work_time_total, @project) then
       # 権限が無ければパス
      @message ||= ''
      @message += '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
      return
    end

    po = WtProjectOrders.where(["uid=-1 and dsp_prj=:d",{:d=>dsp_prj}]).first
    return if po == nil # 対象の表示プロジェクトが無ければパス

    if po.dsp_pos > dst then # 前に持っていく場合
      tgts = WtProjectOrders.where(["uid=-1 and dsp_pos>=:o1 and dsp_pos<:o2",{:o1=>dst, :o2=>po.dsp_pos}]).all
      tgts.each do |mv|
        mv.dsp_pos+=1; mv.save # 順位を一つずつ後へ
      end
      po.dsp_pos=dst; po.save
    end

    if po.dsp_pos < dst then # 後に持っていく場合
      tgts = WtProjectOrders.where(["uid=-1 and dsp_pos<=:o1 and dsp_pos>:o2",{:o1=>dst, :o2=>po.dsp_pos}]).all
      tgts.each do |mv|
        mv.dsp_pos-=1; mv.save # 順位を一つずつ前へ
      end
      po.dsp_pos=dst; po.save
    end
  end

  def calc_total
    ################################################  合計集計計算ループ ########
    @total_cost = 0
    @member_cost = Hash.new
    WtMemberOrder.where(["prj_id=:p",{:p=>@project.id}]).all.each do |i|
      @member_cost[i.user_id] = 0
    end
    @issue_parent = Hash.new # clear cash

    @issue_cost = Hash.new
    @r_issue_cost = Hash.new

    @prj_cost = Hash.new
    @r_prj_cost = Hash.new

    @issue_act_cost = Hash.new
    @r_issue_act_cost = Hash.new

    relay = Hash.new
    WtTicketRelay.all.each do |i|
      relay[i.issue_id] = i.parent
    end

    #当月の時間記録を抽出
    TimeEntry.
        where(["spent_on>=:t1 and spent_on<=:t2 and hours>0",{:t1 => @first_date, :t2 => @last_date}]).
        all.
        each do |time_entry|
      iid = time_entry.issue_id
      uid = time_entry.user_id
      cost = time_entry.hours
      act = time_entry.activity_id
      # 本プロジェクトのユーザの工数でなければパス
      next unless @member_cost.key?(uid)

      issue = Issue.find_by_id(iid)
      next if issue.nil? # チケットが削除されていたらパス
      pid = issue.project_id
      # プロジェクト限定の対象でなければパス
      next if @restrict_project && pid != @restrict_project

      @total_cost += cost
      @member_cost[uid] += cost

      parent_iid = get_parent_issue(relay, iid)
      if !Issue.find_by_id(iid) || !Issue.find_by_id(iid).visible?
        # 表示権限の無い工数があった場合
        iid = -1 # private
        pid = -1 # private
        act = -1 # private
      end
      @issue_cost[iid] ||= Hash.new
      @issue_cost[iid][-1] ||= 0
      @issue_cost[iid][-1] += cost
      @issue_cost[iid][uid] ||= 0
      @issue_cost[iid][uid] += cost

      @prj_cost[pid] ||= Hash.new
      @prj_cost[pid][-1] ||= 0
      @prj_cost[pid][-1] += cost
      @prj_cost[pid][uid] ||= 0
      @prj_cost[pid][uid] += cost

      @issue_act_cost[iid] ||= Hash.new
      @issue_act_cost[iid][uid] ||= Hash.new
      @issue_act_cost[iid][uid][act] ||= 0
      @issue_act_cost[iid][uid][act] += cost

      parent_issue = Issue.find_by_id(parent_iid)
      if parent_issue && parent_issue.visible?
        parent_pid = parent_issue.project_id
      else
        parent_iid = -1
        parent_pid = -1
      end

      @r_issue_cost[parent_iid] ||= Hash.new
      @r_issue_cost[parent_iid][-1] ||= 0
      @r_issue_cost[parent_iid][-1] += cost
      @r_issue_cost[parent_iid][uid] ||= 0
      @r_issue_cost[parent_iid][uid] += cost

      @r_prj_cost[parent_pid] ||= Hash.new
      @r_prj_cost[parent_pid][-1] ||= 0
      @r_prj_cost[parent_pid][-1] += cost
      @r_prj_cost[parent_pid][uid] ||= 0
      @r_prj_cost[parent_pid][uid] += cost

      @r_issue_act_cost[parent_iid] ||= Hash.new
      @r_issue_act_cost[parent_iid][uid] ||= Hash.new
      @r_issue_act_cost[parent_iid][uid][act] ||= 0
      @r_issue_act_cost[parent_iid][uid][act] += cost
    end
  end

  def get_parent_issue(relay, iid)
    @issue_parent ||= Hash.new
    return @issue_parent[iid] if @issue_parent.has_key?(iid)
    issue = Issue.find_by_id(iid)
    return 0 if issue.nil? # issueが削除されていたらそこまで
    @issue_cost[iid] ||= Hash.new

    if relay.has_key?(iid)
      parent_id = relay[iid]
      if parent_id != 0 && parent_id != iid
        parent_id = get_parent_issue(relay, parent_id)
      end
      parent_id = iid if parent_id == 0
    else
      # 関連が登録されていない場合は登録する
      WtTicketRelay.create(:issue_id=>iid, :position=>relay.size, :parent=>0)
      parent_id = iid
    end

    # iid に対する初めての処理
    pid = issue.project_id
    unless @prj_cost.has_key?(pid)
      check = WtProjectOrders.where(["uid=-1 and dsp_prj=:p",{:p=>pid}]).all
      if check.size == 0
        WtProjectOrders.create(:uid=>-1, :dsp_prj=>pid, :dsp_pos=>@prj_cost.size)
      end
    end

    @issue_parent[iid] = parent_id # return
  end

  def make_pack
    # 月間工数表のデータを作成
    @month_pack = {:ref_prjs=>{}, :odr_prjs=>[],
                   :total=>0, :total_by_day=>{},
                   :other=>0, :other_by_day=>{},
                   :count_prjs=>0, :count_issues=>0}
    @month_pack[:total_by_day].default = 0

    # 日毎工数のデータを作成
    @day_pack = {:ref_prjs=>{}, :odr_prjs=>[],
                 :total=>0, :total_by_day=>{},
                 :other=>0, :other_by_day=>{},
                 :count_prjs=>0, :count_issues=>0}
    @day_pack[:total_by_day].default = 0

    # プロジェクト順の表示データを作成
    dsp_prjs = Project.joins("INNER JOIN wt_project_orders ON wt_project_orders.dsp_prj=projects.id").
        where(["wt_project_orders.uid=:u",{:u=>@this_uid}]).
        select("projects.*, wt_project_orders.dsp_pos as dsp_pos").
        order("wt_project_orders.dsp_pos").
        all
    dsp_prjs.each do |prj|
      next if @restrict_project && @restrict_project!=prj.id
      make_pack_prj(@month_pack, prj, prj.dsp_pos)
      make_pack_prj(@day_pack, prj, prj.dsp_pos)
    end
    @prj_odr_max = dsp_prjs.length

    # チケット順の表示データを作成
    dsp_issues = Issue.joins("INNER JOIN user_issue_months ON user_issue_months.issue=issues.id").
        where(["user_issue_months.uid=:u",{:u=>@this_uid}]).
        order("user_issue_months.odr").
        select("issues.*, user_issue_months.odr").
        all
    dsp_issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      month_prj_pack = make_pack_prj(@month_pack, issue.project)
      make_pack_issue(month_prj_pack, issue, issue.odr)
      day_prj_pack = make_pack_prj(@day_pack, issue.project)
      make_pack_issue(day_prj_pack, issue, issue.odr)
    end
    @issue_odr_max = dsp_issues.length

    # 月内の工数を集計
    hours = TimeEntry.
        includes(:issue).
        where(["user_id=:uid and spent_on>=:day1 and spent_on<=:day2",
               {:uid => @this_uid, :day1 => @first_date, :day2 => @last_date}]).
        all
    hours.each do |hour|
      next if @restrict_project && @restrict_project!=hour.project.id
      work_time = hour.hours
      if hour.issue && hour.issue.visible? then
        # 表示項目に工数のプロジェクトがあるかチェック→なければ項目追加
        prj_pack = make_pack_prj(@month_pack, hour.project)

        # 表示項目に工数のチケットがあるかチェック→なければ項目追加
        issue_pack = make_pack_issue(prj_pack, hour.issue)

        issue_pack[:count_hours] += 1

        # 合計時間の計算
        @month_pack[:total] += work_time
        prj_pack[:total] += work_time
        issue_pack[:total] += work_time

        # 日毎の合計時間の計算
        date = hour.spent_on
        @month_pack[:total_by_day][date] += work_time
        prj_pack[:total_by_day][date] += work_time
        issue_pack[:total_by_day][date] += work_time

        if date==@this_date then # 表示日の工数であれば項目追加
          # 表示項目に工数のプロジェクトがあるかチェック→なければ項目追加
          day_prj_pack = make_pack_prj(@day_pack, hour.project)

          # 表示項目に工数のチケットがあるかチェック→なければ項目追加
          day_issue_pack = make_pack_issue(day_prj_pack, hour.issue, NO_ORDER)

          day_issue_pack[:each_entries][hour.id] = hour # 工数エントリを追加
          day_issue_pack[:total] += work_time
          day_prj_pack[:total] += work_time
          @day_pack[:total] += work_time
        end
      else
        # 合計時間の計算
        @month_pack[:total] += work_time
        @month_pack[:other] += work_time

        # 日毎の合計時間の計算
        date = hour.spent_on
        @month_pack[:total_by_day][date] ||= 0
        @month_pack[:total_by_day][date] += work_time
        @month_pack[:other_by_day][date] ||= 0
        @month_pack[:other_by_day][date] += work_time

        if date==@this_date then # 表示日の工数であれば項目追加
          @day_pack[:total] += work_time
          @day_pack[:other] += work_time
        end
      end
    end

    # この日のチケット作成を洗い出す
    next_date = @this_date+1
    t1 = Time.local(@this_date.year, @this_date.month, @this_date.day)
    t2 = Time.local(next_date.year, next_date.month, next_date.day)
    issues = Issue.where(["(author_id = :u and created_on >= :t1 and created_on < :t2) or "+
                              "id in (select journalized_id from journals where journalized_type = 'Issue' and "+
                              "user_id = :u and created_on >= :t1 and created_on < :t2 group by journalized_id)",
                          {:u => @this_user, :t1 => t1, :t2 => t2}]).all

    issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      next if !@this_user.allowed_to?(:log_time, issue.project)
      next if !issue.visible?
      prj_pack = make_pack_prj(@day_pack, issue.project)
      issue_pack = make_pack_issue(prj_pack, issue)
      if issue_pack[:css_classes] == 'wt_iss_overdue'
        issue_pack[:css_classes] = 'wt_iss_overdue_worked'
      else
        issue_pack[:css_classes] = 'wt_iss_worked'
      end
    end
    issues = Issue.
        joins("INNER JOIN issue_statuses ist on ist.id = issues.status_id ").
        joins("LEFT JOIN groups_users on issues.assigned_to_id = group_id").
        where(["1 = 1 and
                (  (issues.assigned_to_id = :u or groups_users.user_id = :u) and
                   issues.start_date < :t2 and
                   ist.is_closed = :closed
                )", {:u => @this_uid, :t2 => t2, :closed => false}]).
        all
    issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      next if !@this_user.allowed_to?(:log_time, issue.project)
      next if !issue.visible?
      prj_pack = make_pack_prj(@day_pack, issue.project)
      issue_pack = make_pack_issue(prj_pack, issue)
      if issue_pack[:css_classes] == 'wt_iss_default'
        issue_pack[:css_classes] = 'wt_iss_assigned'
      elsif issue_pack[:css_classes] == 'wt_iss_worked'
        issue_pack[:css_classes] = 'wt_iss_assigned_worked'
      elsif issue_pack[:css_classes] == 'wt_iss_overdue'
        issue_pack[:css_classes] = 'wt_iss_assigned_overdue'
      elsif issue_pack[:css_classes] == 'wt_iss_overdue_worked'
        issue_pack[:css_classes] = 'wt_iss_assigned_overdue_worked'
      end
    end

    # 月間工数表から工数が無かった項目の削除と項目数のカウント
    @month_pack[:count_issues] = 0
    @month_pack[:odr_prjs].each do |prj_pack|
      prj_pack[:odr_issues].each do |issue_pack|
        if issue_pack[:count_hours]==0 then
          prj_pack[:count_issues] -= 1
        end
      end

      if prj_pack[:count_issues]==0 then
        @month_pack[:count_prjs] -= 1
      else
        @month_pack[:count_issues] += prj_pack[:count_issues]
      end
    end
  end

  def make_pack_prj(pack, new_prj, odr=NO_ORDER)
      # 表示項目に当該プロジェクトがあるかチェック→なければ項目追加
      unless pack[:ref_prjs].has_key?(new_prj.id) then
        prj_pack = {:odr=>odr, :prj=>new_prj,
                    :total=>0, :total_by_day=>{},
                    :ref_issues=>{}, :odr_issues=>[], :count_issues=>0}
        pack[:ref_prjs][new_prj.id] = prj_pack
        pack[:odr_prjs].push prj_pack
        pack[:count_prjs] += 1
        prj_pack[:total_by_day].default = 0
      end
      pack[:ref_prjs][new_prj.id]
  end

  def make_pack_issue(prj_pack, new_issue, odr=NO_ORDER)
      id = new_issue.nil? ? -1 : new_issue.id
      # 表示項目に当該チケットがあるかチェック→なければ項目追加
      unless prj_pack[:ref_issues].has_key?(id) then
        issue_pack = {:odr=>odr, :issue=>new_issue,
                      :total=>0, :total_by_day=>{},
                      :count_hours=>0, :each_entries=>{},
                      :cnt_childrens=>0}
        issue_pack[:total_by_day].default = 0
        if !new_issue.due_date.nil? && new_issue.due_date < @this_date.to_datetime
          issue_pack[:css_classes] = 'wt_iss_overdue'
        else
          issue_pack[:css_classes] = 'wt_iss_default'
        end
        prj_pack[:ref_issues][id] = issue_pack
        prj_pack[:odr_issues].push issue_pack
        prj_pack[:count_issues] += 1
        cnt_childrens = Issue.where(["parent_id = ?", new_issue.id.to_s]).count
        issue_pack[:cnt_childrens] = cnt_childrens
      end
      prj_pack[:ref_issues][id]
  end

  def sum_or_nil(v1, v2)
    if v2.blank?
      v1
    else
      if v1.blank?
        v2
      else
        v1 + v2
      end
    end
  end

  # 重複削除と順序の正規化
  def order_normalization(table, key_column, find_params)
    raise "need table" unless table
    order = find_params[:order]
    raise "need :order" unless order
    update = false

    tgts = table.
        where(find_params[:conditions]).
        order(order).
        all
    keys = []
    tgts.each do |tgt|
      if keys.include?(tgt[key_column]) then
        tgt.destroy
        update = true
      else
        keys.push(tgt[key_column])
        if tgt[order] != keys.length then
          tgt[order] = keys.length
          tgt.save
          update = true
        end
      end
    end
    update
  end

end
