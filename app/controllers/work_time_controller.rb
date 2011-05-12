class WorkTimeController < ApplicationController
  unloadable
#  before_filter :find_project, :authorize

  helper :custom_fields
  include CustomFieldsHelper

  def index
    require_login || return
    @project = nil
    prepare_values;
    ticket_pos;
    prj_pos;
    ticket_del;
    hour_update;
    prepare_tickets_array;
    make_pack
    update_daily_memo;
    set_holiday;
    @custom_fields = TimeEntryCustomField.find(:all);
    @link_params.merge!(:action=>"index");
    render "show"
  end

  def show
    find_project;
    authorize;
    prepare_values;
    ticket_pos;
    prj_pos;
    ticket_del;
    hour_update;
    prepare_tickets_array;
    make_pack
    member_add_del_check;
    update_daily_memo;
    set_holiday;
    @custom_fields = TimeEntryCustomField.find(:all);
    @link_params.merge!(:action=>"show");
  end

  def total
    find_project;
    authorize;
    prepare_values;
    member_add_del_check;
    add_ticket_relay;
    change_member_position;
    change_ticket_position;
    change_project_position;
    calc_total;
    @link_params.merge!(:action=>"total");
  end

  def edit_relay
    find_project;
    authorize;
    prepare_values;
    member_add_del_check;
    add_ticket_relay;
    change_member_position;
    change_ticket_position;
    change_project_position;
    calc_total;
    @link_params.merge!(:action=>"edit_relay");
  end

  def relay_total
    find_project;
    authorize;
    prepare_values;
    member_add_del_check;
    add_ticket_relay;
    change_member_position;
    change_ticket_position;
    change_project_position;
    calc_total;
    @link_params.merge!(:action=>"relay_total");
  end

  def relay_total2
    find_project;
    authorize;
    prepare_values;
    member_add_del_check;
    add_ticket_relay;
    change_member_position;
    change_ticket_position;
    change_project_position;
    calc_total;
    @link_params.merge!(:action=>"relay_total2");
  end

  def popup_select_ticket # チケット選択ウィンドウの内容を返すアクション
    render(:layout=>false);
  end

  def ajax_select_ticket # チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    render(:layout=>false);
  end

  def popup_select_tickets # 複数チケット選択ウィンドウの内容を返すアクション
    render(:layout=>false);
  end

  def ajax_select_tickets # 複数チケット選択ウィンドウにAjaxで挿入(Update)される内容を返すアクション
    render(:layout=>false);
  end

  def ajax_insert_daily # 日毎工数に挿入するAjaxアクション
    prepare_values;
    @custom_fields = TimeEntryCustomField.find(:all);
    render(:layout=>false);
  end

  def ajax_memo_edit # 日毎のメモ入力フォームを出力するAjaxアクション
    render(:layout=>false);
  end

  def ajax_relay_table
    find_project;
    authorize;
    prepare_values;
    member_add_del_check;
    add_ticket_relay;
    change_member_position;
    change_ticket_position;
    change_project_position;
    calc_total;
    @link_params.merge!(:action=>"edit_relay");
    render(:layout=>false);
  end

  def popup_update_done_ratio # 進捗％更新ポップアップ
    issue_id = params[:issue_id];
    @issue = Issue.find_by_id(issue_id);
    if @issue.closed? || !@issue.visible? then
      next if !params.key?(:all);
      @issueHtml = "<del>"+@issue.to_s+"</del>";
    else
      @issueHtml = @issue.to_s;
    end
    render(:layout=>false);
  end

  def ajax_update_done_ratio
    issue_id = params[:issue_id];
    done_ratio = params[:done_ratio];
    @issue = Issue.find_by_id(issue_id);
    if User.current.allowed_to?(:edit_issues, @issue.project) then
      @issue.init_journal(User.current);
      @issue.done_ratio = done_ratio;
      @issue.save;
    end
    render(:layout=>false);
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

    @today = Date.today;
    @this_year = params.key?(:year) ? params[:year].to_i : @today.year;
    @this_month = params.key?(:month) ? params[:month].to_i : @today.month;
    @this_day = params.key?(:day) ? params[:day].to_i : @today.day;
    @this_date = Date.new(@this_year, @this_month, @this_day);
    @last_month = @this_date << 1;
    @next_month = @this_date >> 1;
    @month_str = sprintf("%04d-%02d", @this_year, @this_month);

    @restrict_project = (params.key?(:prj) && params[:prj].to_i > 0) ? params[:prj].to_i : false;

    @first_date = Date.new(@this_year, @this_month, 1);
    @last_date = (@first_date >> 1) - 1;

    @month_names = l(:wt_month_names).split(',');
    @wday_name = l(:wt_week_day_names).split(',');
    @wday_color = ["#faa", "#eee", "#eee", "#eee", "#eee", "#eee", "#aaf"];

    @link_params = {:controller=>"work_time", :id=>@project,
                    :year=>@this_year, :month=>@this_month, :day=>@this_day,
                    :user=>@this_uid, :prj=>@restrict_project};
  end

  def ticket_pos 
    # 重複削除と順序の正規化
    tgts = UserIssueMonth.find(:all, :order=>"odr", :conditions=>["uid=:u",{:u=>@this_uid}])
    unique = []
    tgts.each do |tgt|
      if unique.include?(tgt.issue) then
        tgt.destroy
      else
        unique.push(tgt.issue)
        if tgt.odr != unique.length then
          tgt.odr = unique.length
          tgt.save
        end
      end
    end

    # 表示チケット順序変更求処理
    if params.key?("ticket_pos") && params[:ticket_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i;
      dst = $2.to_i;
      src = UserIssueMonth.find(:first, :conditions=>
            ["uid=:u and issue=:i", {:u=>@this_uid,:i=>tid}]);
      if src && src.uid == @crnt_uid then
        if src.odr > dst then # チケットを前にもっていく場合
          tgts = UserIssueMonth.find(:all, :conditions=>
          ["uid=:u and odr>=:o1 and odr<:o2",
          {:u=>src.uid, :o1=>dst, :o2=>src.odr}]);
          tgts.each do |tgt|
            tgt.odr += 1; tgt.save;# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save;
        else # チケットを後に持っていく場合
          tgts = UserIssueMonth.find(:all, :conditions=>
          ["uid=:u and odr<=:o1 and odr>:o2",
          {:u=>src.uid, :o1=>dst, :o2=>src.odr}]);
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save;# 順位をひとつずつ後へ
          end
          src.odr = dst; src.save;
        end
      end
    end
  end

  def prj_pos
    # 重複削除と順序の正規化
    tgts = WtProjectOrders.find(:all, :order=>"dsp_pos", :conditions=>["uid=:u",{:u=>@this_uid}])
    unique = []
    tgts.each do |tgt|
      if unique.include?(tgt.dsp_prj) then
        tgt.destroy
      else
        unique.push(tgt.dsp_prj)
        if tgt.dsp_pos != unique.length then
          tgt.dsp_pos = unique.length
          tgt.save
        end
      end
    end

    # 表示プロジェクト順序変更求処理
    if params.key?("prj_pos") && params[:prj_pos] =~ /^(.*)_(.*)$/ then
      tid = $1.to_i;
      dst = $2.to_i;
      src = WtProjectOrders.find(:first, :conditions=>["uid=:u and dsp_prj=:d",{:u=>@this_uid, :d=>tid}]);

      if src then
        if src.dsp_pos > dst then # チケットを前にもっていく場合
          tgts = WtProjectOrders.find(:all, :conditions=>[
                 "uid=:u and dsp_pos>=:o1 and dsp_pos<:o2",
                 {:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}]);
          tgts.each do |tgt|
            tgt.dsp_pos += 1; tgt.save;# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save;
        else # チケットを後に持っていく場合
          tgts = WtProjectOrders.find(:all, :conditions=>[
                 "uid=:u and dsp_pos<=:o1 and dsp_pos>:o2",
                 {:u=>@this_uid, :o1=>dst, :o2=>src.dsp_pos}]);
          tgts.each do |tgt|
            tgt.dsp_pos -= 1; tgt.save;# 順位をひとつずつ後へ
          end
          src.dsp_pos = dst; src.save;
        end
      end
    end
  end

  def ticket_del # チケット削除処理
    if params.key?("ticket_del") then
      if params["ticket_del"]=="closed" then # 終了チケット全削除の場合
          issues = Issue.find(:all,
                      :joins=>"INNER JOIN user_issue_months ON user_issue_months.issue=issues.id",
                      :conditions=>["user_issue_months.uid=:u",{:u=>@this_uid}]);
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
      {:u=>@this_uid,:i=>params["ticket_del"]}]);
      if src && src.uid == @crnt_uid then # 削除対象に工数が残っていないか確認
        entry = TimeEntry.find(:all, :conditions =>
                   ["user_id=:uid and spent_on>=:day1 and spent_on<=:day2 and hours>0 and issue_id=:i",
                   {:uid => src.uid, :day1 => @first_date, :day2 => @last_date, :i=>src.issue}]);
        if entry.size != 0 then
        @message = '<div style="color:#f00;">'+l(:wt_no_permission_del)+'</div>';
        else
          tgts = UserIssueMonth.find(:all, :conditions=>
                 ["uid=:u and odr>:o",{:u=>src.uid, :o=>src.odr}]);
          tgts.each do |tgt|
            tgt.odr -= 1; tgt.save;# 当該チケット表示より後ろの全チケットの順位をアップ
          end
          src.destroy# 当該チケット表示を削除
        end
      end
    end
  end

  def hour_update # *********************************** 工数更新要求の処理
    return if @this_uid != @crnt_uid;

    @message ||= "";
    # 新規工数の登録
    if params["new_time_entry"] then
      params["new_time_entry"].each do |issue_id, valss|
        issue = Issue.find_by_id(issue_id);
        next if issue.nil?;
        next if !issue.visible?
        next if !User.current.allowed_to?(:log_time, issue.project)
        valss.each do |count, vals|
          next if vals['hours'] == "";
          if !vals['activity_id'] then
            @message += '<div style="background:#faa;">Error: Issue'+issue_id+': No Activities!</div><br>';
             next;
          end
          new_entry = TimeEntry.new(:project => issue.project, :issue => issue, :user => User.current, :spent_on => @this_date)
          new_entry.attributes = vals;
          new_entry.save;
          msg = hour_update_check_error(new_entry, issue.id);
          @message += '<div style="background:#faa;">'+msg+'</div><br>' if msg != "";
        end
      end
    end

    # 既存工数の更新
    if params["time_entry"] then
      params["time_entry"].each do |id, vals|
        tm = TimeEntry.find(id);
        if vals["hours"] == "" then
          # 工数指定が空文字の場合は工数項目を削除
          tm.destroy;
        else
          tm.attributes = vals;
          tm.save;
          msg = hour_update_check_error(tm, tm.issue.id);
          @message += '<div style="background:#faa;">'+msg+'</div><br>' if msg != "";
        end
      end
    end
  end

  def hour_update_check_error(obj, issue_id)
    return "" if obj.errors.empty?;
    p obj;
    str = "ERROR:#"+issue_id.to_s+"<br>";
    obj.errors.each do |attr, msg|
      next if msg.nil?
      if attr == "base"
        str += msg
      else
        str += "&#171; " + l("field_#{attr}") + " &#187; " + msg + "<br>" unless attr == "custom_values"
      end
    end
    # retrieve custom values error messages
    if obj.errors[:custom_values]
      obj.custom_values.each do |v|
        v.errors.each do |attr, msg|
          next if msg.nil?
          str += "&#171; " + v.custom_field.name + " &#187; " + msg + "<br>"
        end
      end
    end
    return str;
  end

  def prepare_tickets_array # チケット表示項目を作成
    # 既存の表示項目を取得
    disp = UserIssueMonth.find(:all, :order=>"odr",
      :conditions=>["uid=:u",{:u=>@this_uid}])
    # 今回表示するチケットIDの配列を作成
    @disp_prj_issues = Hash.new;
    @disp_issues = [];
    disp.each do |d|
      findIssues = Issue.find(:all, :conditions=>["id=:i", {:i=>d.issue}]);
      if findIssues.size == 0 then # もし当該チケットが削除されていたら
        d.destroy; # 表示項目も削除する
        next;
      end
      prj = findIssues[0].project_id;
      next if @restrict_project && prj != @restrict_project;
      @disp_issues |= [d.issue];
      if @disp_prj_issues.key?(prj) then
        @disp_prj_issues[prj].push([d.issue,d.odr]);
      else
        @disp_prj_issues[prj] = [[d.issue,d.odr]];
      end
    end
    @disp_count = @disp_issues.size;
    add_issues = []; #追加候補初期化

    #当該ユーザの当月の工数に新しいチケットが無いか確認
    time_entry = TimeEntry.find(:all, :conditions =>
        ["user_id=:uid and spent_on>=:day1 and spent_on<=:day2 and hours>0",
        {:uid => @this_uid, :day1 => @first_date, :day2 => @last_date}])

    time_entry.each do |e| #各工数のチケットを追加対象にする
      add_issues |= [e.issue.id] if e.issue;
    end

    add_issues.each do |add| # 追加対象をチェックして
      issue = Issue.find_by_id(add);
      next if issue.nil?; # 削除されていたらパス
      next if !issue.visible?
      prj = issue.project_id;
      next if @restrict_project && prj != @restrict_project;
      if (@disp_issues & [add]).size==0 then #既存の表示項目に当該チケットが無かったら
        # 追加する
        @disp_count += 1;
        @disp_issues |= [add];
        if @disp_prj_issues.key?(prj) then
          @disp_prj_issues[prj].push([add,@disp_count]);
        else
          @disp_prj_issues[prj] = [[add,@disp_count]];
        end

        if @this_uid==@crnt_uid then #本人ならDBに書き込んでしまう
          UserIssueMonth.create(:uid=>@this_uid, :issue=>add, :odr=>@disp_count)
        end
      end
    end

    # この日のチケット作成を洗い出す
    @worked_issues = [];
    next_date = @this_date+1
    t1 = Time.local(@this_date.year, @this_date.month, @this_date.day);
    t2 = Time.local(next_date.year, next_date.month, next_date.day);
    issues = Issue.find(:all, :conditions=>["author_id=:u and created_on>=:t1 and created_on<:t2",
        {:u=>@this_uid, :t1=>t1, :t2=>t2}]);
    issues.each do |issue|
      next if !issue.visible?
      @worked_issues |= [issue.id];
    end
    # この日のチケット操作を洗い出す
    journals = Journal.find(:all, :conditions=>
        ["journalized_type='Issue' and user_id=:u and created_on>=:t1 and created_on<:t2",
        {:u=>@this_uid, :t1=>t1, :t2=>t2}]);
    journals.each do |j|
      @worked_issues |= [j.journalized_id];
    end

    input_issues = @disp_issues.dup;
    @input_prj_issues = Hash.new;
    @disp_prj_issues.each do |k,v|
      @input_prj_issues[k] = v.dup;
    end
    @worked_issues.each do |i|
      next if input_issues.include?(i); #既存の項目は追加しない
      issue = Issue.find_by_id(i);
      next if issue.nil?; # 削除されていたらパス
      next if !issue.visible?
      p = issue.project_id;
      next if @restrict_project && p != @restrict_project; #プロジェクト制限チェック
      input_issues.push(i);
      if @input_prj_issues.key?(p) then
        @input_prj_issues[p].push([i, -1]); #既存ハッシュに要素追加
      else
        @input_prj_issues[p] = [[i, -1]]; #新規ハッシュに配列を追加
      end
    end

    # 各ユーザの表示プロジェクトに不足がないか確認
    prj_odr = WtProjectOrders.find(:all, :conditions=>["uid=:u",{:u=>@this_uid}]);
    prj_odr_num = prj_odr.size;
    prjs = @input_prj_issues.keys; # 表示すべき全Prjから
    prj_odr.each do |po|
      prjs.delete(po.dsp_prj); # 既存の表示Prjを削除すると、追加すべきPrjが残る
    end
    prjs.each do |prj| # 追加すべきPrjをDB登録
      prj_odr_num += 1;
      WtProjectOrders.create(:uid=>@this_uid, :dsp_prj=>prj, :dsp_pos=>prj_odr_num);
    end
  end
  
  def member_add_del_check
    #---------------------------------------- メンバーの増減をチェック
    members = Member.find(:all, :conditions=>
    ["project_id=:prj", {:prj=>@project.id}]);
    members.each do |mem| # 現メンバーの中で
      user = User.find_by_id(mem.user_id);
      next if user.nil?;
      if user.active? then # アクティブで
        odr = WtMemberOrder.find(:first, :conditions=>["user_id=:u and prj_id=:p", {:u=>mem.user_id, :p=>@project.id}]);
        if !odr then # 未登録の者を追加
          n = WtMemberOrder.new(:user_id=>mem.user_id, :position=>WtMemberOrder.find(:all).size+1,:prj_id=>@project.id);
          n.save;
        end
      end
    end

    @members = [];
    WtMemberOrder.find(:all, :order=>"position", :conditions=>["prj_id=:p",{:p=>@project.id}]).each do |mo| # 登録されている者の中で
      mem = Member.find(:first, :conditions=>["user_id=:u and project_id=:p", {:u=>mo.user_id, :p=>@project.id}]);
      if !mem then # 登録されていないものは削除
        mo.destroy;
      else # 登録されていても
        user = User.find_by_id(mo.user_id);
        if user.nil? || !(user.active?) then # アクティブでないものは
          mo.destroy; # 削除
        else
          @members.push([user.id,user.to_s]);
        end
      end
    end
  end

  def update_daily_memo # 日ごとメモの更新
    text = params["memo"] || return; # メモ更新のpostがあるか？
    year = params["year"] || return;
    month = params["month"] || return;
    day = params["day"] || return;
    user_id = params["user"] || return;

    # ユーザと日付で既存のメモを検索
    date = Date.new(year.to_i,month.to_i,day.to_i);
    find = WtDailyMemo.find(:all, :conditions=>["day=:d and user_id=:u",{:d=>date,:u=>user_id}]);
    while find.size > 1 do # もし複数見つかったら
      (find.shift).destroy; # 消しておく
    end

    if find.size != 0 then
      # 既存のメモがあれば
      record = find.shift;
      record.description = text;
      record.updated_on = Time.now;
      record.save; # 更新
    else
      # 既存のメモがなければ新規作成
      now = Time.now;
      WtDailyMemo.create(:user_id=>user_id,
                         :day=>date,
                         :created_on=>now,
                         :updated_on=>now,
                         :description=>text);
    end
  end

  ################################ 休日設定
  def set_holiday
    user_id = params["user"] || return;
    if set_date = params['set_holiday'] then
      WtHolidays.create(:holiday=>set_date, :created_on=>Time.now, :created_by=>user_id);
    end
    if del_date = params['del_holiday'] then
      holidays = WtHolidays.find(:all, :conditions=>["holiday=:h and deleted_on is null",{:h=>del_date}]);
      holidays.each do |h|
        h.deleted_on = Time.now;
        h.deleted_by = user_id;
        h.save;
      end
    end
  end

  def add_ticket_relay
    ################################### チケット付け替え関係処理
    if params.key?("ticket_relay") && params[:ticket_relay]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        child_id = $1.to_i;
        parent_id = $2.to_i;

        anc_id = parent_id;
        while anc_id != 0 do
          break if anc_id == child_id;
          relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>anc_id}]);
          break if !relay;
          anc_id = relay.parent;
        end

        if anc_id != child_id then
          relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>child_id}]);
          if relay then
            relay.parent = parent_id;
            relay.save;
          end
        else
          @message = '<div style="background:#faa;">'+l(:wt_loop_relay)+'</div>';
          return;
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>';
        return;
      end
    end
  end

  def change_member_position
    ################################### メンバー順序変更処理
    if params.key?("member_pos") && params[:member_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        uid = $1.to_i;
        dst = $2.to_i;
        mem = WtMemberOrder.find(:first, :conditions=>["prj_id=:p and user_id=:u",{:p=>@project.id, :u=>uid}]);
        if mem then
          if mem.position > dst then # メンバーを前に持っていく場合
            tgts = WtMemberOrder.find(:all, :conditions=>
            ["prj_id=:p and position>=:p1 and position<:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}]);
            tgts.each do |mv|
              mv.position+=1; mv.save; # 順位を一つずつ後へ
            end
            mem.position=dst; mem.save;
          end
          if mem.position < dst then # メンバーを後に持っていく場合
            tgts = WtMemberOrder.find(:all, :conditions=>
            ["prj_id=:p and position<=:p1 and position>:p2",{:p=>@project.id, :p1=>dst, :p2=>mem.position}]);
            tgts.each do |mv|
              mv.position-=1; mv.save; # 順位を一つずつ前へ
            end
            mem.position=dst; mem.save;
          end
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>';
        return;
      end
    end
  end

  def change_ticket_position
    ################################### チケット表示順序変更処理
    if params.key?("ticket_pos") && params[:ticket_pos]=~/^(.*)_(.*)$/ then
      if User.current.allowed_to?(:edit_work_time_total, @project) then
        issue_id = $1.to_i;
        dst = $2.to_i;
        relay = WtTicketRelay.find(:first, :conditions=>["issue_id=:i",{:i=>issue_id}]);
        if relay then
          if relay.position > dst then # 前に持っていく場合
            tgts = WtTicketRelay.find(:all, :conditions=>
            ["position>=:p1 and position<:p2",{:p1=>dst, :p2=>relay.position}]);
            tgts.each do |mv|
              mv.position+=1; mv.save; # 順位を一つずつ後へ
            end
            relay.position=dst; relay.save;
          end
          if relay.position < dst then # 後に持っていく場合
            tgts = WtTicketRelay.find(:all, :conditions=>
            ["position<=:p1 and position>:p2",{:p1=>dst, :p2=>relay.position}]);
            tgts.each do |mv|
              mv.position-=1; mv.save; # 順位を一つずつ前へ
            end
            relay.position=dst; relay.save;
          end
        end
      else
        @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>';
        return;
      end
    end
  end

  def change_project_position
    ################################### プロジェクト表示順序変更処理
    return if !params.key?("prj_pos"); # 位置変更パラメータが無ければパス
    return if !(params[:prj_pos]=~/^(.*)_(.*)$/); # パラメータの形式が正しくなければパス
    dsp_prj = $1.to_i;
    dst = $2.to_i;

    if !User.current.allowed_to?(:edit_work_time_total, @project) then
       # 権限が無ければパス
      @message = '<div style="background:#faa;">'+l(:wt_no_permission)+'</div>';
      return;
    end

    po = WtProjectOrders.find(:first, :conditions=>["uid=-1 and dsp_prj=:d",{:d=>dsp_prj}]);
    return if po == nil; # 対象の表示プロジェクトが無ければパス

    if po.dsp_pos > dst then # 前に持っていく場合
      tgts = WtProjectOrders.find(:all, :conditions=> ["uid=-1 and dsp_pos>=:o1 and dsp_pos<:o2",{:o1=>dst, :o2=>po.dsp_pos}]);
      tgts.each do |mv|
        mv.dsp_pos+=1; mv.save; # 順位を一つずつ後へ
      end
      po.dsp_pos=dst; po.save;
    end

    if po.dsp_pos < dst then # 後に持っていく場合
      tgts = WtProjectOrders.find(:all, :conditions=> ["uid=-1 and dsp_pos<=:o1 and dsp_pos>:o2",{:o1=>dst, :o2=>po.dsp_pos}]);
      tgts.each do |mv|
        mv.dsp_pos-=1; mv.save; # 順位を一つずつ前へ
      end
      po.dsp_pos=dst; po.save;
    end
  end

  def calc_total
    ################################################  合計集計計算ループ ########
    @total_cost = 0;
    @member_cost = Hash.new;
    WtMemberOrder.find(:all, :conditions=>["prj_id=:p",{:p=>@project.id}]).each do |i|
      @member_cost[i.user_id] = 0;
    end
    @issue_cost = Hash.new;
    @r_issue_cost = Hash.new;
    relay = Hash.new;
    WtTicketRelay.find(:all).each do |i|
      relay[i.issue_id] = i.parent;
      @issue_cost[i.issue_id] = Hash.new;
      @r_issue_cost[i.issue_id] = Hash.new;
    end
    @prj_cost = Hash.new;
    @r_prj_cost = Hash.new;
    WtProjectOrders.find(:all, :conditions=>"uid=-1").each do |i|
      @prj_cost[i.dsp_prj] = Hash.new;
      @r_prj_cost[i.dsp_prj] = Hash.new;
    end

    #当月の時間記録を抽出
    TimeEntry.find(:all, :conditions =>
    ["spent_on>=:t1 and spent_on<=:t2 and hours>0",
    {:t1 => @first_date, :t2 => @last_date}]).each do |time_entry|
      iid = time_entry.issue_id;
      uid = time_entry.user_id;
      cost = time_entry.hours;

      # 本プロジェクトのユーザの工数でなければパス
      next unless @member_cost.key?(uid);

      issue = Issue.find_by_id(iid);
      next if issue.nil?; # チケットが削除されていたらパス
      next if !issue.visible?
      pid = issue.project_id;
      # プロジェクト限定の対象でなければパス
      next if @restrict_project && pid != @restrict_project;

      @total_cost += cost;
      @member_cost[uid] += cost;

      # 親チケットを探索する
      parent_iid = iid;
      while true do
        parent_issue = Issue.find_by_id(parent_iid);
        break if parent_issue.nil?; # チケットが削除されていたらそこまで
        break if !parent_issue.visible?

        if !(relay.key?(parent_iid)) then
          # まだ登録されていないチケットの場合、追加処理を行う
          relay[parent_iid] = 0;
          @issue_cost[parent_iid] = Hash.new;
          @r_issue_cost[parent_iid] = Hash.new;
          WtTicketRelay.create(:issue_id=>parent_iid, :position=>relay.size, :parent=>0);
        end

        parent_pid = parent_issue.project_id;
        if !(@prj_cost.key?(parent_pid)) then
          # まだ登録されていないプロジェクトの場合、追加処理を行う
          @prj_cost[parent_pid] = Hash.new;
          @r_prj_cost[parent_pid] = Hash.new;
          WtProjectOrders.create(:uid=>-1, :dsp_prj=>parent_pid, :dsp_pos=>@prj_cost.size);
        end

        (@issue_cost[parent_iid])[uid] ||= 0;
        (@issue_cost[parent_iid])[-1] ||= 0;
        (@prj_cost[parent_pid])[uid] ||= 0;
        (@prj_cost[parent_pid])[-1] ||= 0;

        break if relay[parent_iid] == 0;
        # このチケットに親チケットがある場合は、その親チケットについて同じ処理を繰り返す
        parent_iid = relay[parent_iid];
      end

      @issue_cost[iid] ||= Hash.new;
      (@issue_cost[iid])[uid] ||= 0;
      (@issue_cost[iid])[uid] += cost;
      (@issue_cost[iid])[-1] ||= 0;
      (@issue_cost[iid])[-1] += cost;

      @prj_cost[pid] ||= Hash.new;
      (@prj_cost[pid])[uid] ||= 0;
      (@prj_cost[pid])[uid] += cost;
      (@prj_cost[pid])[-1] ||= 0;
      (@prj_cost[pid])[-1] += cost;

      @r_issue_cost[parent_iid] ||= Hash.new;
      (@r_issue_cost[parent_iid])[uid] ||= 0;
      (@r_issue_cost[parent_iid])[-1] ||= 0;
      @r_prj_cost[parent_pid] ||= Hash.new;
      (@r_prj_cost[parent_pid])[uid] ||= 0;
      (@r_prj_cost[parent_pid])[-1] ||= 0;

      (@r_issue_cost[parent_iid])[uid] += cost;
      (@r_issue_cost[parent_iid])[-1] += cost;
      (@r_prj_cost[parent_pid])[uid] += cost;
      (@r_prj_cost[parent_pid])[-1] += cost;
    end
  end

  def make_pack
    # 月間工数表のデータを作成
    @month_pack = {:ref_prjs=>{}, :odr_prjs=>[],
                   :total=>0, :total_by_day=>{},
                   :count_prjs=>0, :count_issues=>0,
                   :prj_odr_max=>0, :issue_odr_max=>0}

    # プロジェクト順の表示データを作成
    dsp_prjs = Project.find(:all, :joins=>"INNER JOIN wt_project_orders ON wt_project_orders.dsp_prj=projects.id",
                          :select=>"projects.*, wt_project_orders.dsp_pos",
                          :conditions=>["wt_project_orders.uid=:u",{:u=>@this_uid}],
                          :order=>"wt_project_orders.dsp_pos")
    dsp_prjs.each do |prj|
      make_pack_add_prj(@month_pack, prj, prj.dsp_pos)
      @month_pack[:prj_odr_max] = prj.dsp_pos if @month_pack[:prj_odr_max].to_i < prj.dsp_pos.to_i
    end

    # チケット順の表示データを作成
    dsp_issues = Issue.find(:all, :joins=>"INNER JOIN user_issue_months ON user_issue_months.issue=issues.id",
                            :select=>"issues.*, user_issue_months.odr",
                            :conditions=>["user_issue_months.uid=:u",{:u=>@this_uid}],
                            :order=>"user_issue_months.odr")
    dsp_issues.each do |issue|
      make_pack_add_prj(@month_pack, issue.project, -1)
      prj_pack = @month_pack[:ref_prjs][issue.project_id]
      make_pack_add_issue(prj_pack, issue, issue.odr)
      @month_pack[:issue_odr_max] = issue.odr if @month_pack[:issue_odr_max].to_i < issue.odr.to_i
    end

    # 月内の工数を集計
    hours = TimeEntry.find(:all, :conditions =>
        ["user_id=:uid and spent_on>=:day1 and spent_on<=:day2",
        {:uid => @this_uid, :day1 => @first_date, :day2 => @last_date}])
    hours.each do |hour|
      # 表示項目に工数のプロジェクトがあるかチェック→なければ項目追加
      make_pack_add_prj(@month_pack, hour.project, -1)
      prj_pack = @month_pack[:ref_prjs][hour.project_id]

      # 表示項目に工数のチケットがあるかチェック→なければ項目追加
      make_pack_add_issue(prj_pack, hour.issue, -1)
      issue_pack = prj_pack[:ref_issues][hour.issue_id]

      issue_pack[:count_hours] += 1;

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
    end

    @month_pack[:count_issues] = 0;
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

  def make_pack_add_prj(pack, new_prj, odr)
      # 表示項目に当該プロジェクトがあるかチェック→なければ項目追加
      unless pack[:ref_prjs].has_key?(new_prj.id) then
        prj_pack = {:odr=>odr, :prj=>new_prj, :total=>0, :total_by_day=>{}, :ref_issues=>{}, :odr_issues=>[], :count_issues=>0}
        pack[:ref_prjs][new_prj.id] = prj_pack
        pack[:odr_prjs].push prj_pack
        pack[:count_prjs] += 1;
      end
  end

  def make_pack_add_issue(prj_pack, new_issue, odr)
      # 表示項目に当該チケットがあるかチェック→なければ項目追加
      unless prj_pack[:ref_issues].has_key?(new_issue.id) then
        issue_pack = {:odr=>odr, :issue=>new_issue, :total=>0, :total_by_day=>{}, :count_hours=>0}
        prj_pack[:ref_issues][new_issue.id] = issue_pack
        prj_pack[:odr_issues].push issue_pack
        prj_pack[:count_issues] += 1;
      end
  end

end
