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

function set_ticket_relay(pop_url, rep_url, child)
{
  var parent = showModalDialog(pop_url, window, "dialogWidth:600px;dialogHeight:480px");
  if(parent!=null) {
    jQuery.ajax({
      url:rep_url+"&ticket_relay="+child+"_"+parent,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#ticket'+child).html(response);
      }
    });
  }
}

function update_done_ratio(pop_url, rep_url, issue_id)
{
  var done_ratio = showModalDialog(pop_url+"&issue_id="+issue_id,
        window, "dialogWidth:500px;dialogHeight:150px");
  if(done_ratio!=null){
    jQuery.ajax({
      url:rep_url+"&issue_id="+issue_id+"&done_ratio="+done_ratio,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#done_ratio'+issue_id).html(response);
      }
    });

    var drs = document.getElementsByName("done_ratio"+issue_id);
    for(var i = 0; i < drs.length; i++) {
      drs[i].innerHTML = "["+done_ratio+"&#37;]";
    }
  }
}

function del_ticket_relay(rep_url, child)
{
    jQuery.ajax({
        url:rep_url+"&ticket_relay="+child+"_0",
        data:{asynchronous:true, method:'get'
      },
      success:function(response){
        jQuery('#ticket'+child).html(response);
      }
    });
}

function checkKey(e, finish_func)
{
  if (!e) var e = window.event;
  if(e.keyCode == 13) {
    finish_func();
    return false;
  }
  else
    return e;
}

function ajax_select_tickets(rep_url)
{
    jQuery.ajax({
      url:rep_url,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#tickets').html(response);
      }
    });
}

//------------------------------------------------- for show.html.erb
var add_ticket_count = 1;
function add_ticket(pop_url, ajax_url)
{
    var tickets = showModalDialog(pop_url, window, "dialogWidth:600px;dialogHeight:480px");
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

function dup_ticket(ajax_url, insert_pos, id)
{
    jQuery.ajax({
      url:ajax_url+"&add_issue="+id+"&count="+add_ticket_count,
      data:{asynchronous:true, method:'get'},
      success:function(response){
        jQuery('#'+insert_pos).after(response);
      }
    });
  add_ticket_count ++;
}

function edit_memo(ajax_url)
{
    jQuery.ajax({
      url:ajax_url,
      data:{asynchronous:true, method:'get'},
      success: function(response){
        jQuery('#memo-wiki').html(response);
      }
    });
}

//---------------------------------------- for popup_update_done_ratio.html.erb
function ratio_inputed()
{
  returnValue = document.getElementById("input_ratio").value;
  close();
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

//------------- for popup_select_tickets.html.erb, ajax_select_tickets.html.erb
function tickets_inputed()
{
  var vals = document.getElementById("input_ids").value;
  var tickets = vals.split(',');
  returnValue=tickets;
  close();
}

function tickets_selected(issue_id)
{
  returnValue = [issue_id];
  close();
}

function tickets_checked()
{
  var issue_ids = new Array;
  for(i=0; e = document.forms[0].elements[i]; i++) {
    if(e.checked)
      issue_ids.push(e.value);
  }
  returnValue = issue_ids;
  close();
}
