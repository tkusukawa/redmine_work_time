module WorkTimeHelper
  def print_issue_cost(issue)
    issue_cost_est = issue.estimated_hours;
    return "" unless issue_cost_est;
    issue_cost = TimeEntry.sum(:hours, :conditions=>["issue_id=:i",{:i=>issue.id}]);
    return sprintf("(%1.1f/%1.1f)",issue_cost,issue_cost_est);
  end

  def print_issue_cost_rate(issue)
    issue_cost_est = issue.estimated_hours;
    return "" unless issue_cost_est;
    issue_cost = TimeEntry.sum(:hours, :conditions=>["issue_id=:i",{:i=>issue.id}]);
    return sprintf("%1.0f",issue_cost/issue_cost_est*100);
  end
end
