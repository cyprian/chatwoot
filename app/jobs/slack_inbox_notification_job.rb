class SlackInboxNotificationJob < ApplicationJob
  queue_as :medium

  retry_on Slack::Web::Api::Errors::SlackError, wait: :polynomially_longer, attempts: 5

  def perform(configuration, event_name, resource)
    SlackNotifications::DeliveryService.new(
      configuration: configuration,
      event_name: event_name,
      resource: resource
    ).perform
  end
end
