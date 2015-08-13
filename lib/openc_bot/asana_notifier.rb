module AsanaNotifier

  extend self

  def create_failed_bot_task(params)
    client = Asana::Client.new { |c| c.authentication :api_token, params[:asana_api_key] }
    all_teams = client.teams.find_by_organization(:organization => params[:workspace])
    bot_team = all_teams.detect{ |team| team.name.downcase == 'bots' }
    tag_name = params[:tag]
    bot_team_projects = client.projects.find_by_team(:team => bot_team.id)
    failed_bot_project = bot_team_projects.detect{ |project| project.name.downcase == 'failed external bots' } || client.projects.create_in_team(:team => bot_team.id, :name => 'Failed External Bots')

    # see if there's already a task for this failed bot
    return unless task = client.tasks.find_by_project(:projectId => failed_bot_project.id, :per_page => 100).detect { |t| t.tags.any?{ |t| t.name == tag_name} }
    # otherwise create a new one
    task ||= client.tasks.create(:name => params[:title], :workspace => params[:workspace], :notes => params[:description], :projects => [failed_bot_project.id])

    tag = client.tags.create(:workspace => params[:workspace], :name => tag_name)
    task.add_tag :tag => tag.id
  end

end