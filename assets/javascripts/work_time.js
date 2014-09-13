function ticket_pos(url, issue, pos, max)
{
  var new_pos = prompt("Destination No.", pos);
  if(new_pos != null) {
    if((new_pos>=1) && (new_pos<=max))
      location.replace(url+"&ticket_pos="+issue+"_"+new_pos);
    else 
      alert("Out of range!");
  }
}

function prj_pos(url, prj, pos, max)
{
  var new_pos = prompt("Destination No.", pos);
  if(new_pos != null) {
    if((new_pos>=1) && (new_pos<=max))
      location.replace(url+"&prj_pos="+prj+"_"+new_pos);
    else 
      alert("Out of range!");
  }
}

function member_pos(url, user_id, pos, max)
{
  var new_pos = prompt("Distination No.", pos);
  if(new_pos != null) {
    if((new_pos>=1) && (new_pos<=max))
      location.replace(url+"&member_pos="+user_id+"_"+new_pos);
    else 
      alert("Out of rnage!");
  }
}

function set_ticket_relay_core(req_url, child_id, parent_id) {
  if (typeof jQuery == "function") {
    jQuery.ajax({
      url:req_url+"&ticket_relay="+child_id+"_"+parent_id,
      data:{asynchronous:true, method:'get'},
      success:function(response) {
        jQuery('#ticket'+child_id).html(response);
      }
    });
  } else {
    new Ajax.Updater('ticket'+child_id,
      req_url+"&ticket_relay="+child_id+"_"+parent_id,
      {asynchronous:true, method:'get'});
  }
}

function set_ticket_relay(pop_url, req_url, child_id)
{
  var parent_id = showModalDialog(pop_url, window, "dialogWidth:600px;dialogHeight:480px");
  if (parent_id != null) {
    set_ticket_relay_core(req_url, child_id, parent_id);
  }
}

function set_ticket_relay_by_issue_relation(req_url) {
  if (typeof jQuery == "function") {
    $('[data-has-parent="false"]').each(function(i, v) {
      var child_id = v.attributes['data-issue-id'].value || '';
      var parent_id = v.attributes['data-redmine-parent-id'].value || '';
      if (child_id == ''|| parent_id == '')  return;
      set_ticket_relay_core(req_url, child_id, parent_id);
    });
  } else {
    alert('sorry not supported!');
  }
}

function input_done_ratio(ajax_url, issue_id) {
  jQuery.ajax({
    url: ajax_url + "&issue_id=" + issue_id,
    data: {asynchronous: true, method: 'get'},
    success: function (response) {
      jQuery('[name="done_ratio'+ issue_id+'"]:first').replaceWith(response);
    }
  });
}

function update_done_ratio(ajax_url, issue_id) {
  var done_ratio = $('#input_ratio'+issue_id).val();
  jQuery.ajax({
    url:ajax_url+"&issue_id="+issue_id+"&done_ratio="+done_ratio,
    data:{asynchronous:true, method:'get'},
    success:function(response){
      jQuery('[name="done_ratio'+ issue_id+'"]').replaceWith(response);
    }
  });
}

function del_ticket_relay(rep_url, child)
{
  if( typeof jQuery == "function" ) {
    jQuery.ajax({
        url:rep_url+"&ticket_relay="+child+"_0",
        data:{asynchronous:true, method:'get'
      },
      success:function(response){
        jQuery('#ticket'+child).html(response);
      }
    });
  }
  else {
    new Ajax.Updater('ticket'+child,
      rep_url+"&ticket_relay="+child+"_0",
      {asynchronous:true, method:'get'});
  }
}

function checkKey(e, finish_func, arg1, arg2)
{
  if (!e) var e = window.event;
  if(e.keyCode == 13) {
    finish_func(arg1,arg2);
    return false;
  }
  else
    return e;
}

function ajax_select_tickets(rep_url)
{
  if( typeof jQuery == "function" ) {
    jQuery.ajax({
      url:rep_url,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#tickets').replaceWith(response);
      }
    });
  }
  else {
    new Ajax.Updater('tickets',
      rep_url,
      {asynchronous:true, method:'get'});
  }
}

//------------------------------------------------- for show.html.erb
var add_ticket_count = 1;
function add_ticket(ajax_url) {
    jQuery.ajax({
      url: ajax_url,
      data: {asynchronous: true, method: 'get'},
      success: function (response) {
        jQuery('#add_ticket_button').replaceWith(response);
      }
    })
}

function dup_ticket(ajax_url, insert_pos, id)
{
  if( typeof jQuery == "function" ) {
    jQuery.ajax({
      url:ajax_url+"&add_issue="+id+"&count="+add_ticket_count,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#'+insert_pos).after(response);
      }
    });
  }
  else {
    new Ajax.Updater( insert_pos,
      ajax_url+"&add_issue="+id+"&count="+add_ticket_count,
      {insertion:Insertion.After, method:'get'});
  }
  add_ticket_count ++;
}

function edit_memo(ajax_url)
{
  if( typeof jQuery == "function" ) {
    jQuery.ajax({
      url:ajax_url,
      data:{asynchronous:true, method:'get'},
      success: function(response){
        jQuery('#memo-wiki').html(response);
      }
    });
  }
  else {
    new Ajax.Updater('memo-wiki',
      ajax_url,
      {asynchronous:true, method:'get'});
  }
}

//--------------- for popup_select_ticket.html.erb, ajax_select_ticket.html.erb
function ticket_inputed()
{
  returnValue = document.getElementById("input_id").value;
  close();
}

function ticket_selected(issue_id)
{
  returnValue = issue_id;
  close();
}

function tickets_insert(ajax_url, tickets)
{
  for(i=0; i<tickets.length;i++) {
    jQuery.ajax({
      url:ajax_url+"&add_issue="+tickets[i]+"&count="+add_ticket_count,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#time_input_table_bottom').before(response);
      }
    });
    add_ticket_count ++;
  }
}

function tickets_inputed(ajax_url)
{
  var vals = document.getElementById("input_ids").value;
  var tickets = vals.split(',');
  tickets_insert(ajax_url, tickets);
}

function tickets_selected(ajax_url, issue_id)
{
  var tickets = [issue_id];
  tickets_insert(ajax_url, tickets);
}

function tickets_checked(ajax_url)
{
  var $checked = $('[name="ticket_select_check"]:checked');
  var tickets = $checked.map(function(i,e){return $(this).val()});
  tickets_insert(ajax_url, tickets);
}

function statusUpdateOnDailyTable(name) {
  obj = document.getElementsByName(name)[0];
  obj.style.backgroundColor = '#cfc';
  index = obj.selectedIndex;
  v = obj.options[index].value;
  obj.options[index].value = 'M'+v;
}

//------------- for user_day_table.html.erb
function sumDayTimes() {
  var total=0;
  var dayInputs;
  
  // List all Input elemnets of the page
  dayInputs = document.getElementsByTagName("input");
  for (var i=0; i<dayInputs.length; i++) {
    // Consider only those with an id containing the strings 'time_entry' and 'hours'
    if ((dayInputs[i].id.indexOf("time_entry") >= 0) && (dayInputs[i].id.indexOf("hours") >= 0)) {
      if (dayInputs[i].value && !isNaN(parseFloat(dayInputs[i].value))) {
      // add the number to the total if it is a valid number
        total = total + parseFloat(dayInputs[i].value);
     }
    }
  }
  // Set the total value to the new number, changing the style to indicate 
  // it is not saved, and adding the saved value as a flyover indication
  var originalValue;
  document.getElementById("currentTotal").innerHTML = total.toFixed(1);
  document.getElementById("currentTotal").style = 'color:#FF0000;';
return true;
}
