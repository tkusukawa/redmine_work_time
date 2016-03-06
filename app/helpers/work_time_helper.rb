module WorkTimeHelper
  def print_issue_cost(issue)
    return "" unless issue
    issue_cost_est = issue.estimated_hours
    return "" unless issue_cost_est
    issue_cost = TimeEntry.where(:issue_id => issue.id).sum(:hours).to_f
    return sprintf("(%1.1f/%1.1f)",issue_cost,issue_cost_est)
  end

  def print_issue_cost_rate(issue)
    return "" unless issue
    issue_cost_est = issue.estimated_hours
    return "" unless issue_cost_est
    issue_cost = TimeEntry.where(:issue_id => issue.id).sum(:hours).to_f
    return sprintf("%1.0f",issue_cost/issue_cost_est*100)
  end

  def wk_pretty_issue_name(issue, issue_id = issue.id)
    if issue.nil? || !issue.visible?
      content_tag :del, issue_id
    elsif issue.closed?
      content_tag :del, issue.to_s
    else
      issue.to_s
    end
  end
end
