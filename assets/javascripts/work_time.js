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