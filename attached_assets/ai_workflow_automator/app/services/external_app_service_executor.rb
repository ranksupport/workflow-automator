class ExternalAppServiceExecutor
  def self.execute(service_name, action_name = nil, params = {})
    new(service_name, action_name, params).execute
  end

  def initialize(service_name, action_name = nil, params = {})
    @service_name = service_name
    @action_name = action_name
    @params = params
  end

  def execute
    service_instance = load_service
    
    if @action_name.present?
      execute_specific_action(service_instance)
    else
      execute_general(service_instance)
    end
  end

  private

  def load_service
    service_class_name = @service_name.classify
    service_class = service_class_name.constantize
    service_class.new
  rescue NameError => e
    raise "Service '#{@service_name}' not found. Please ensure the service file exists at app/models/service/#{@service_name.downcase}.rb"
  end

  def execute_specific_action(service_instance)
    unless service_instance.respond_to?(@action_name)
      available_actions = service_instance.respond_to?(:available_actions) ? service_instance.available_actions : []
      raise "Action '#{@action_name}' not available for service '#{@service_name}'. Available actions: #{available_actions.join(', ')}"
    end

    service_instance.send(@action_name, @params)
  end

  def execute_general(service_instance)
    if service_instance.respond_to?(:execute)
      service_instance.execute(@params)
    else
      raise "Service '#{@service_name}' does not implement execute method"
    end
  end
end
