class WorkTimeController < ApplicationController
  unloadable
  #  before_filter :find_project, :authorize

  helper :custom_fields
  include CustomFieldsHelper

  NO_ORDER = -1

  def index
    require_login || return
    @project = nil
    prepare_values
    ticket_pos
    prj_pos
    ticket_del
    hour_update
    make_pack
    update_daily_memo
    set_holiday
    @custom_fields = TimeEntryCustomField.find(:all)
    @link_params.merge!(:action=>"index")
    if !params.key?(:user) then
      redirect_to @link_params
    else
      render "show"
    end
  end

  def show
    find_project
    authorize
    prepare_values
    ticket_pos
    prj_pos
    ticket_del
    hour_update
    make_pack
    member_add_del_check
    update_daily_memo
    set_holiday
    @custom_fields = TimeEntryCustomField.find(:all)
    @link_params.merge!(:action=>"show")
    if !params.key?(:user) then
      redirect_to @link_params
    end
  end

  def total
    find_project
    authorize
    prepare_values
    member_add_del_check
    add_ticket_relay
    change_member_position
    change_ticket_position
    change_project_position
    calc_total
    @link_params.merge!(:action=>"total")
  end

  def edit_relay
    find_project
    authorize
    prepare_values
    member_add_del_check
    add_ticket_relay
    change_member_position
    change_ticket_position
    change_project_position
    calc_total
    @link_params.merge!(:action=>"edit_relay")
  end

  def relay_total
    find_project
    authorize
    prepare_values
    member_add_del_check
    add_ticket_relay
    change_member_position
    change_ticket_position
    change_project_position
    calc_total
    @link_params.merge!(:action=>"relay_total")
  end

  def relay_total2
    find_project
    authorize
    prepare_values
    member_add_del_check
    add_ticket_relay
    change_member_position
    change_ticket_position
    change_project_position
    calc_total
    @link_params.merge!(:action=>"relay_total2")
  end

  def popup_select_ticket # チケット選択ウィンドウの内容を返すアクション
    render(:layout=>false)
  end

  def ajax_select_ticket # チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    render(:layout=>false)
  end

  def popup_select_tickets # 複数チケット選択ウィンドウの内容を返すアクション
    render(:layout=>false)
  end

  def ajax_select_tickets # 複数チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    render(:layout=>false)
  end

  def ajax_insert_daily # 日毎工数に挿入するAjaxアクション
    prepare_values

    uid = params[:user]
    add_issue_id = params[:add_issue]
    count = params[:count]
    if @this_uid==@crnt_uid then
      add_issue = Issue.find_by_id(add_issue_id)
      if add_issue && add_issue.visible? then
        prj = add_issue.project
        if User.current.allowed_to?(:log_time, prj) then
          if add_issue.closed? then
            @issueHtml = "<del>"+add_issue.to_s+"</del>"
          else
            @issueHtml = add_issue.to_s
          end

          @suffix = "["+add_issue_id+"]["+count+"]"

          @activities = []
          prj.activities.each do |act|
            @activities.push([act.name, act.id])
          end

          @custom_fields = TimeEntryCustomField.find(:all)
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

          unless UserIssueMonth.exists?(["uid=:u and issue=:i",{:u=>uid, :i=>add_issue_id}]) then
            # 既存のレコードが存在していなければ追加
            UserIssueMonth.create(:uid=>uid, :issue=>add_issue_id,
              :odr=>UserIssueMonth.count(:conditions=>["uid=:u",{:u=>uid}])+1)
          end
        end
      end
    end

    render(:layout=>false)
  end

  def ajax_memo_edit # 日毎のメモ入力フォームを出力するAjaxアクション
    render(:layout=>false)
  end

  def ajax_relay_table
    find_project
    authorize
    prepare_values
    member_add_del_check
    add_ticket_relay
    change_member_position
    change_ticket_position
    change_project_position
    calc_total
    @link_params.merge!(:action=>"edit_relay")
    render(:layout=>false)
  end

  def popup_update_done_ratio # 進捗％更新ポップアップ
    issue_id = params[:issue_id]
    @issue = Issue.find_by_id(issue_id)
    if @issue.closed? || !@issue.visible? then
      next if !params.key?(:all)
      @issueHtml = "<del>"+@issue.to_s+"</del>"
    else
      @issueHtml = @issue.to_s
    end
    render(:layout=>false)
  end

  def ajax_update_done_ratio
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

    @today = Date.today
    @this_year = params.key?(:year) ? params[:year].to_i : @today.year
    @this_month = params.key?(:month) ? params[:month].to_i : @today.month
    @this_day = params.key?(:day) ? params[:day].to_i : @today.day
    @this_date = Date.new(@this_year, @this_month, @this_day)
    @last_month = @this_date << 1
    @next_month = @this_date >> 1
    @month_str = sprintf("%04d-%02d", @this_year, @this_month)

    @restrict_project = (params.key?(:prj) && params[:prj].to_i > 0) ? params[:prj].to_i : false

    @first_date = Date.new(@this_year, @this_month, 1)
    @last_date = (@first_date >> 1) - 1

    @month_names = l(:wt_month_names).split(',')
    @wday_name = l(:wt_week_day_names).split(',')
    @wday_color = ["#faa", "#eee", "#eee", "#eee", "#eee", "#eee", "#aaf"]

    @link_params = {:controller=>"work_time", :id=>@project,
                    :year=>@this_year, :month=>@this_month, :day=>@this_day,
                    :user=>@this_uid, :prj=>@restrict_project}
  end

  def ticket_pos
    return if @this_uid != @crnt_uid

    # 重複削除と順序の正規化
    if order_normalization(UserIssueMonth, :issue, :order=>"odr", :conditions=>["uid=:u",{:u=>@this_uid}]) then
      @message = '<div style="background:#faa;">Warning: normalize UserIssueMonth</div>'
      return
    end

    # 表示チケット順序変更求処理
    if params.key?("ticket_pos") && params[:ticket_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i
      dst = $2.to_i
      src = UserIssueMonth.find(:first, :conditions=>
            ["uid=:u and issue=:i", {:u=>@this_uid,:i=>tid}])
      if src then # ポジション変更の場合
        if src.odr > dst then # チケットを前にもっていく場合
          tgts = UserIssueMonth.find(:all, :conditions=>
          ["uid=:u and odr>=:o1 and odr<:o2",
          {:u=>src.uid, :o1=>dst, :o2=>src.odr}])
          tgts.each do |tgt|
            tgt.odr += 1; tgt.save# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save
        else # チケットを後に持っていく場合
          tgts = UserIssueMonth.find(:all, :conditions=>
          ["uid=:u and odr<=:o1 and odr>:o2",
          {:u=>src.uid, :o1=>dst, :o2=>src.odr}])
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save
        end
      else
        # 新規のポジションの場合
        tgts = UserIssueMonth.find(:all, :conditions=> ["uid=:u and odr>=:o1",
                                                  {:u=>@this_uid, :o1=>dst}])
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
      @message = '<div style="background:#faa;">Warning: normalize WtProjectOrders</div>'
      return
    end

    # 表示プロジェクト順序変更求処理
    if params.key?("prj_pos") && params[:prj_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i
      dst = $2.to_i
      src = WtProjectOrders.find(:first, :conditions=>["uid=:u and dsp_prj=:d",{:u=>@this_uid, :d=>tid}])

      if src then # ポジション変更の場合
        if src.dsp_pos > dst then # チケットを前にもっていく場合
          tgts = WtProjectOrders.find(:all, :conditions=>[
                 "uid=:u and dsp_pos>=:o1 and dsp_pos<:o2",
                 {:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}])
          tgts.each do |tgt|
            tgt.dsp_pos += 1; tgt.save# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save
        else # チケットを後に持っていく場合
          tgts = WtProjectOrders.find(:all, :conditions=>[
                 "uid=:u and dsp_pos<=:o1 and dsp_pos>:o2",
                 {:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}])
          tgts.each do |tgt|
            tgt.dsp_pos -= 1; tgt.save# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save
        end
      else
        # 新規のポジションの場合
          tgts = WtProjectOrders.find(:all, :conditions=>["uid=:u and dsp_pos>=:o1",
                                       {:u=>@this_uid, :o1=>dst}])
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
          issues = Issue.find(:all,
                      :joins=>"INNER JOIN user_issue_months ON user_issue_months.issue=issues.id",
                      :conditions=>["user_issue_months.uid=:u",{:u=>@this_uid}])
          issues.each do |issue|
            if issue.closed? then
              tgt = UserIssueMonth.find(:first,
                       :conditions=>["uid=:u and issue=:i",{:u=>@this_uid,:i=>issue.id}])
              tgt.destroy
            end
          end
          return
      end

      # チケット番号指定の削除の場合
      src = UserIssueMonth.find(:first, :conditions=>
      ["uid=:u and issue=:i",
      {:u=>@this_uid,:i=>params["ticket_del"]}])
      if src && src.uid == @crnt_uid then
          tgts = UserIssueMonth.find(:all, :conditions=>
                 ["uid=:u and odr>:o",{:u=>src.uid, :o=>src.odr}])
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save# 当該チケット表示より後ろの全チケットの順位をアップ
          end
          src.destroy# 当該チケット表示を削除
      end
    end
  end

  def hour_update # *********************************** 工数更新要求の処理
    return if @this_uid != @crnt_uid

    @message ||= ""
    # 新規工数の登録
    if params["new_time_entry"] then
      params["new_time_entry"].each do |issue_id, valss|
        issue = Issue.find_by_id(issue_id)
        next if issue.nil?
        next if !issue.visible?
        next if !User.current.allowed_to?(:log_time, issue.project)
        valss.each do |count, vals|
          next if vals['hours'] == ""
          if !vals['activity_id'] then
            @message += '<div style="background:#faa;">Error: Issue'+issue_id+': No Activities!</div><br>'
             next
          end
          new_entry = TimeEntry.new(:project => issue.project, :issue => issue, :user => User.current, :spent_on => @this_date)
          new_entry.attributes = vals
          new_entry.save
          msg = hour_update_check_error(new_entry, issue.id)
          @message += '<div style="background:#faa;">'+msg+'</div><br>' if msg != ""
        end
      end
    end

    # 既存工数の更新
    if params["time_entry"] then
      params["time_entry"].each do |id, vals|
        tm = TimeEntry.find(id)
        if vals["hours"] == "" then
          # 工数指定が空文字の場合は工数項目を削除
          tm.destroy
        else
          tm.attributes = vals
          tm.save
          msg = hour_update_check_error(tm, tm.issue.id)
          @message += '<div style="background:#faa;">'+msg+'</div><br>' if msg != ""
        end
      end
    end
  end

  def hour_update_check_error(obj, issue_id)
    return "" if obj.errors.empty?
    p obj
    str = "ERROR:#"+issue_id.to_s+"<br>"
    obj.errors.each do |attr, msg|
      next if msg.nil?
      if attr == "base"
        str += msg
      else
        str += "&#171; " + l("field_#{attr}") + " &#187; " + msg + "<br>" unless attr == "custom_values"
      end
    end
    # retrieve custom values error messages
    if obj.errors[:custom_values] then
      obj.custom_values.each do |v|
        v.errors.each do |attr, msg|
          next if msg.nil?
          str += "&#171; " + v.custom_field.name + " &#187; " + msg + "<br>"
        end
      end
    end
    return str
  end

  def member_add_del_check
    #---------------------------------------- メンバーの増減をチェック
    members = Member.find(:all, :conditions=>
    ["project_id=:prj", {:prj=>@project.id}])
    members.each do |mem| # 現メンバーの中で
      user = User.find_by_id(mem.user_id)
      next if user.nil?
      if user.active? then # アクティブで
        odr = WtMemberOrder.find(:first, :conditions=>["user_id=:u and prj_id=:p", {:u=>mem.user_id, :p=>@project.id}])
        if !odr then # 未登録の者を追加
          n = WtMemberOrder.new(:user_id=>mem.user_id, :position=>WtMemberOrder.find(:all).size+1,:prj_id=>@project.id)
          n.save
        end
      end
    end

    @members = []
    WtMemberOrder.find(:all, :order=>"position", :conditions=>["prj_id=:p",{:p=>@project.id}]).each do |mo| # 登録されている者の中で
      mem = Member.find(:first, :conditions=>["user_id=:u and project_id=:p", {:u=>mo.user_id, :p=>@project.id}])
      if !mem then # 登録されていないものは削除
        mo.destroy
      else # 登録されていても
        user = User.find_by_id(mo.user_id)
        if user.nil? || !(user.active?) then # アクティブでないものは
          mo.destroy # 削除
        else
          @members.push([user.id,user.to_s])
        end
      end
    end
  end

  def update_daily_memo # 日ごとメモの更新
    text = params["memo"] || return # メモ更新のpostがあるか？
    year = params["year"] || return
    month = params["month"] || return
    day = params["day"] || return
    user_id = params["user"] || return

    # ユーザと日付で既存のメモを検索
    date = Date.new(year.to_i,month.to_i,day.to_i)
    find = WtDailyMemo.find(:all, :conditions=>["day=:d and user_id=:u",{:d=>date,:u=>user_id}])
    while find.size > 1 do # もし複数見つかったら
      (find.shift).destroy # 消しておく
    end

    if find.size != 0 then
      # 既存のメモがあれば
      record = find.shift
      record.description = text
      record.updated_on = Time.now
      record.save # 更新
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
      holidays = WtHolidays.find(:all, :conditions=>["holiday=:h and deleted_on is null",{:h=>del_date}])
      holidays.each do |h|
        h.deleted_on = Time.now
        h.deleted_by = user_id
        h.save
      end
    end
  end

  def add_ticket_relay
    ################################### チケット付け替え関係処理
    if params.key?("ticket_relay") && params[:ticket_relay]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        child_id = $1.to_i
        parent_id = $2.to_i

        anc_id = parent_id
        while anc_id != 0 do
          break if anc_id == child_id
          relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>anc_id}])
          break if !relay
          anc_id = relay.parent
        end

        if anc_id != child_id then
          relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>child_id}])
          if relay then
            relay.parent = parent_id
            relay.save
          end
        else
          @message = '<div style="background:#faa;">'+l(:wt_loop_relay)+'</div>'
          return
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
        return
      end
    end
  end

  def change_member_position
    ################################### メンバー順序変更処理
    if params.key?("member_pos") && params[:member_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        uid = $1.to_i
        dst = $2.to_i
        mem = WtMemberOrder.find(:first, :conditions=>["prj_id=:p and user_id=:u",{:p=>@project.id, :u=>uid}])
        if mem then
          if mem.position > dst then # メンバーを前に持っていく場合
            tgts = WtMemberOrder.find(:all, :conditions=>
            ["prj_id=:p and position>=:p1 and position<:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}])
            tgts.each do |mv|
              mv.position+=1; mv.save # 順位を一つずつ後へ
            end
            mem.position=dst; mem.save
          end
          if mem.position < dst then # メンバーを後に持っていく場合
            tgts = WtMemberOrder.find(:all, :conditions=>
            ["prj_id=:p and position<=:p1 and position>:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}])
            tgts.each do |mv|
              mv.position-=1; mv.save # 順位を一つずつ前へ
            end
            mem.position=dst; mem.save
          end
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
        return
      end
    end
  end

  def change_ticket_position
    # 重複削除と順序の正規化
    if order_normalization(WtTicketRelay, :issue_id, :order=>"position") then
      @message = '<div style="background:#faa;">Warning: normalize WtTicketRelay</div>'
      return
    end

    ################################### チケット表示順序変更処理
    if params.key?("ticket_pos") && params[:ticket_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        issue_id = $1.to_i
        dst = $2.to_i
        relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>issue_id}])
        if relay then
          if relay.position > dst then # 前に持っていく場合
            tgts = WtTicketRelay.find(:all, :conditions=>
            ["position>=:p1 and position<:p2",{:p1=>dst, :p2=>relay.position}])
            tgts.each do |mv|
              mv.position+=1; mv.save # 順位を一つずつ後へ
            end
            relay.position=dst; relay.save
          end
          if relay.position < dst then # 後に持っていく場合
            tgts = WtTicketRelay.find(:all, :conditions=>
            ["position<=:p1 and position>:p2",{:p1=>dst, :p2=>relay.position}])
            tgts.each do |mv|
              mv.position-=1; mv.save # 順位を一つずつ前へ
            end
            relay.position=dst; relay.save
          end
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
        return
      end
    end
  end


  def change_project_position
    # 重複削除と順序の正規化
    if order_normalization(WtProjectOrders, :dsp_prj, :order=>"dsp_pos", :conditions=>"uid=-1") then
      @message = '<div style="background:#faa;">Warning: normalize WtProjectOrders</div>'
      return
    end

    ################################### プロジェクト表示順序変更処理
    return if !params.key?("prj_pos") # 位置変更パラメータが無ければパス
    return if !(params[:prj_pos]=~/^(.*)_(.*)$/) # パラメータの形式が正しくなければパス
    dsp_prj = $1.to_i
    dst = $2.to_i

    if !User.current.allowed_to?(:edit_work_time_total, @project) then
       # 権限が無ければパス
      @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>'
      return
    end

    po = WtProjectOrders.find(:first, :conditions=>["uid=-1 and dsp_prj=:d",{:d=>dsp_prj}])
    return if po == nil # 対象の表示プロジェクトが無ければパス

    if po.dsp_pos > dst then # 前に持っていく場合
      tgts = WtProjectOrders.find(:all, :conditions=> ["uid=-1 and dsp_pos>=:o1 and dsp_pos<:o2",{:o1=>dst, :o2=>po.dsp_pos}])
      tgts.each do |mv|
        mv.dsp_pos+=1; mv.save # 順位を一つずつ後へ
      end
      po.dsp_pos=dst; po.save
    end

    if po.dsp_pos < dst then # 後に持っていく場合
      tgts = WtProjectOrders.find(:all, :conditions=> ["uid=-1 and dsp_pos<=:o1 and dsp_pos>:o2",{:o1=>dst, :o2=>po.dsp_pos}])
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
    WtMemberOrder.find(:all, :conditions=>["prj_id=:p",{:p=>@project.id}]).each do |i|
      @member_cost[i.user_id] = 0
    end
    @issue_cost = Hash.new
    @r_issue_cost = Hash.new
    relay = Hash.new
    WtTicketRelay.find(:all).each do |i|
      relay[i.issue_id] = i.parent
      @issue_cost[i.issue_id] = Hash.new
      @r_issue_cost[i.issue_id] = Hash.new
    end
    @prj_cost = Hash.new
    @r_prj_cost = Hash.new
    WtProjectOrders.find(:all, :conditions=>"uid=-1").each do |i|
      @prj_cost[i.dsp_prj] = Hash.new
      @r_prj_cost[i.dsp_prj] = Hash.new
    end

    #当月の時間記録を抽出
    TimeEntry.find(:all, :conditions =>
    ["spent_on>=:t1 and spent_on<=:t2 and hours>0",
    {:t1 => @first_date, :t2 => @last_date}]).each do |time_entry|
      iid = time_entry.issue_id
      uid = time_entry.user_id
      cost = time_entry.hours

      # 本プロジェクトのユーザの工数でなければパス
      next unless @member_cost.key?(uid)

      issue = Issue.find_by_id(iid)
      next if issue.nil? # チケットが削除されていたらパス
      next if !issue.visible?
      pid = issue.project_id
      # プロジェクト限定の対象でなければパス
      next if @restrict_project && pid != @restrict_project

      @total_cost += cost
      @member_cost[uid] += cost

      # 親チケットを探索する
      parent_iid = iid
      while true do
        parent_issue = Issue.find_by_id(parent_iid)
        break if parent_issue.nil? # チケットが削除されていたらそこまで
        break if !parent_issue.visible?

        if !(relay.key?(parent_iid)) then
          # まだ登録されていないチケットの場合、追加処理を行う
          relay[parent_iid] = 0
          @issue_cost[parent_iid] = Hash.new
          @r_issue_cost[parent_iid] = Hash.new
          WtTicketRelay.create(:issue_id=>parent_iid, :position=>relay.size, :parent=>0)
        end

        parent_pid = parent_issue.project_id
        if !(@prj_cost.key?(parent_pid)) then
          # まだ登録されていないプロジェクトの場合、追加処理を行う
          @prj_cost[parent_pid] = Hash.new
          @r_prj_cost[parent_pid] = Hash.new
          WtProjectOrders.create(:uid=>-1, :dsp_prj=>parent_pid, :dsp_pos=>@prj_cost.size)
        end

        (@issue_cost[parent_iid])[uid] ||= 0
        (@issue_cost[parent_iid])[-1] ||= 0
        (@prj_cost[parent_pid])[uid] ||= 0
        (@prj_cost[parent_pid])[-1] ||= 0

        break if relay[parent_iid] == 0
        # このチケットに親チケットがある場合は、その親チケットについて同じ処理を繰り返す
        parent_iid = relay[parent_iid]
      end

      @issue_cost[iid] ||= Hash.new
      (@issue_cost[iid])[uid] ||= 0
      (@issue_cost[iid])[uid] += cost
      (@issue_cost[iid])[-1] ||= 0
      (@issue_cost[iid])[-1] += cost

      @prj_cost[pid] ||= Hash.new
      (@prj_cost[pid])[uid] ||= 0
      (@prj_cost[pid])[uid] += cost
      (@prj_cost[pid])[-1] ||= 0
      (@prj_cost[pid])[-1] += cost

      @r_issue_cost[parent_iid] ||= Hash.new
      (@r_issue_cost[parent_iid])[uid] ||= 0
      (@r_issue_cost[parent_iid])[-1] ||= 0
      @r_prj_cost[parent_pid] ||= Hash.new
      (@r_prj_cost[parent_pid])[uid] ||= 0
      (@r_prj_cost[parent_pid])[-1] ||= 0

      (@r_issue_cost[parent_iid])[uid] += cost
      (@r_issue_cost[parent_iid])[-1] += cost
      (@r_prj_cost[parent_pid])[uid] += cost
      (@r_prj_cost[parent_pid])[-1] += cost
    end
  end

  def make_pack
    # 月間工数表のデータを作成
    @month_pack = {:ref_prjs=>{}, :odr_prjs=>[],
                   :total=>0, :total_by_day=>{},
                   :count_prjs=>0, :count_issues=>0}

    # 日毎工数のデータを作成
    @day_pack = {:ref_prjs=>{}, :odr_prjs=>[],
                 :total=>0, :total_by_day=>{},
                 :count_prjs=>0, :count_issues=>0}

    # プロジェクト順の表示データを作成
    dsp_prjs = Project.find(:all, :joins=>"INNER JOIN wt_project_orders ON wt_project_orders.dsp_prj=projects.id",
                          :select=>"projects.*, wt_project_orders.dsp_pos",
                          :conditions=>["wt_project_orders.uid=:u",{:u=>@this_uid}],
                          :order=>"wt_project_orders.dsp_pos")
    dsp_prjs.each do |prj|
      next if @restrict_project && @restrict_project!=prj.id
      make_pack_prj(@month_pack, prj, prj.dsp_pos)
      make_pack_prj(@day_pack, prj, prj.dsp_pos)
    end
    @prj_odr_max = dsp_prjs.length

    # チケット順の表示データを作成
    dsp_issues = Issue.find(:all, :joins=>"INNER JOIN user_issue_months ON user_issue_months.issue=issues.id",
                            :select=>"issues.*, user_issue_months.odr",
                            :conditions=>["user_issue_months.uid=:u",{:u=>@this_uid}],
                            :order=>"user_issue_months.odr")
    dsp_issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      month_prj_pack = make_pack_prj(@month_pack, issue.project)
      make_pack_issue(month_prj_pack, issue, issue.odr)
      day_prj_pack = make_pack_prj(@day_pack, issue.project)
      make_pack_issue(day_prj_pack, issue, issue.odr)
    end
    @issue_odr_max = dsp_issues.length

    # 月内の工数を集計
    hours = TimeEntry.find(:all, :conditions =>
        ["user_id=:uid and spent_on>=:day1 and spent_on<=:day2",
        {:uid => @this_uid, :day1 => @first_date, :day2 => @last_date}])
    hours.each do |hour|
      next if @restrict_project && @restrict_project!=hour.project.id
      # 表示項目に工数のプロジェクトがあるかチェック→なければ項目追加
      prj_pack = make_pack_prj(@month_pack, hour.project)

      # 表示項目に工数のチケットがあるかチェック→なければ項目追加
      issue_pack = make_pack_issue(prj_pack, hour.issue)

      issue_pack[:count_hours] += 1

      # 合計時間の計算
      work_time = hour.hours
      @month_pack[:total] += work_time
      prj_pack[:total] += work_time
      issue_pack[:total] += work_time
      
      # 日毎の合計時間の計算
      date = hour.spent_on
      @month_pack[:total_by_day][date] ||= 0
      @month_pack[:total_by_day][date] += work_time
      prj_pack[:total_by_day][date] ||= 0
      prj_pack[:total_by_day][date] += work_time
      issue_pack[:total_by_day][date] ||= 0
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
    end

    # この日のチケット作成を洗い出す
    next_date = @this_date+1
    t1 = Time.local(@this_date.year, @this_date.month, @this_date.day)
    t2 = Time.local(next_date.year, next_date.month, next_date.day)
    issues = Issue.find(:all, :conditions=>["author_id=:u and created_on>=:t1 and created_on<:t2",
        {:u=>@this_uid, :t1=>t1, :t2=>t2}])
    issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      prj_pack = make_pack_prj(@day_pack, issue.project)
      issue_pack = make_pack_issue(prj_pack, issue)
      issue_pack[:worked] = true;
    end
    # この日のチケット操作を洗い出す
    issues = Issue.find(:all, :joins=>"INNER JOIN journals ON journals.journalized_id=issues.id",
                        :conditions=>["journals.journalized_type='Issue' and
                                       journals.user_id=:u and
                                       journals.created_on>=:t1 and
                                       journals.created_on<:t2",
                                       {:u=>@this_uid, :t1=>t1, :t2=>t2}])
    issues.each do |issue|
      next if @restrict_project && @restrict_project!=issue.project.id
      prj_pack = make_pack_prj(@day_pack, issue.project)
      issue_pack = make_pack_issue(prj_pack, issue)
      issue_pack[:worked] = true;
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
      end
      pack[:ref_prjs][new_prj.id]
  end

  def make_pack_issue(prj_pack, new_issue, odr=NO_ORDER)
      # 表示項目に当該チケットがあるかチェック→なければ項目追加
      unless prj_pack[:ref_issues].has_key?(new_issue.id) then
        issue_pack = {:odr=>odr, :issue=>new_issue,
                      :total=>0, :total_by_day=>{},
                      :count_hours=>0, :each_entries=>{}}
        prj_pack[:ref_issues][new_issue.id] = issue_pack
        prj_pack[:odr_issues].push issue_pack
        prj_pack[:count_issues] += 1
      end
      prj_pack[:ref_issues][new_issue.id]
  end

  # 重複削除と順序の正規化
  def order_normalization(table, key_column, find_params)
    raise "need table" unless table
    order = find_params[:order]
    raise "need :order" unless order
    update = false

    tgts = table.find(:all, find_params)
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
