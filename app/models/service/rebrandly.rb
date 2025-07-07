class Rebrandly < BaseService
  def self.base_url
    'https://api.rebrandly.com/v1'
  end

  def available_actions
    [
      'create_link',
      'get_link',
      'update_link',
      'delete_link',
      'list_links'
    ]
  end

  def execute(params = {})
    action = params[:action] || params['action']
    
    case action
    when 'create_link'
      create_link(params)
    when 'get_link'
      get_link(params)
    when 'update_link'
      update_link(params)
    when 'delete_link'
      delete_link(params)
    when 'list_links'
      list_links(params)
    else
      raise "Unknown action: #{action}"
    end
  end

  def execute_event(event, config = {})
    case event.name.downcase
    when 'create_link', 'shorten_url'
      create_link(config)
    when 'get_link', 'retrieve_link'
      get_link(config)
    when 'update_link'
      update_link(config)
    when 'delete_link'
      delete_link(config)
    when 'list_links'
      list_links(config)
    else
      raise "Unknown event: #{event.name}"
    end
  end

  private

  def create_link(params)
    payload = {
      destination: params[:destination] || params['destination'],
      slashtag: params[:slashtag] || params['slashtag'],
      title: params[:title] || params['title']
    }.compact

    raise "Destination URL is required" unless payload[:destination]

    post('/links', { body: payload.to_json, headers: { 'Content-Type' => 'application/json' } })
  end

  def get_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    get("/links/#{link_id}")
  end

  def update_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    payload = {
      destination: params[:destination] || params['destination'],
      slashtag: params[:slashtag] || params['slashtag'],
      title: params[:title] || params['title']
    }.compact

    put("/links/#{link_id}", { body: payload.to_json, headers: { 'Content-Type' => 'application/json' } })
  end

  def delete_link(params)
    link_id = params[:link_id] || params['link_id']
    raise "Link ID is required" unless link_id

    delete("/links/#{link_id}")
  end

  def list_links(params = {})
    query_params = {
      limit: params[:limit] || params['limit'] || 25,
      last: params[:last] || params['last']
    }.compact

    query_string = query_params.empty? ? '' : "?#{query_params.to_query}"
    get("/links#{query_string}")
  end
end
