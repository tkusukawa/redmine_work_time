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

function set_ticket_relay_by_issue_relation(ajax_url) {
  $('[id^=ticket_relay_]').each(function(){
    var issue_id = $(this).attr('id').replace(/.*([^_]+)$/, "$1");
    jQuery.ajax({
      url: ajax_url + '&issue_id=' + issue_id,
      data:{asynchronous:true, method:'get'},
      success: function(response) {
        jQuery('#ticket_relay_'+issue_id).html(response);
      }
    });
  })
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

function checkEnter(e)
{
  if (!e) var e = window.event;
  if(e.keyCode == 13)
    return true;
  else
    return false;
}

//------------------------------------------------- for show.html.erb
var add_ticket_count = 1;

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
      var val = dayInputs[i].value;
      if (val) {
        var vals = val.match(/^([\d\.]+)$/);
        if (vals) {
          // add the number to the total if it is a valid number
          total = total + parseFloat(vals[1]);
        }
        else {
          vals = val.match(/^(\d+)m$/);
          if(vals) {
            total = total + parseFloat(vals[1])/60;
          }
          else {
            vals = val.match(/^(\d+):(\d+)$/);
            if(vals) {
              total = total + parseFloat(vals[1]) + parseFloat(vals[2])/60;
            }
          }
        }
      }
    }
  }
  // Set the total value to the new number, changing the style to indicate 
  // it is not saved, and adding the saved value as a flyover indication
  var originalValue;
  document.getElementById("currentTotal").innerHTML = total.toFixed(2);
  document.getElementById("currentTotal").style = 'color:#FF0000;';
  return true;
}
