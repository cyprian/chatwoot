class Api::V1::Accounts::SlackInboxConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_inbox

  def show
    render json: configuration_payload(@inbox.slack_inbox_configuration)
  end

  def update
    configuration = @inbox.slack_inbox_configuration || @inbox.build_slack_inbox_configuration(account: Current.account)
    configuration.update!(configuration_params)
    render json: configuration_payload(configuration)
  end

  def destroy
    @inbox.slack_inbox_configuration&.destroy!
    head :no_content
  end

  def test
    configuration = @inbox.slack_inbox_configuration
    raise ActiveRecord::RecordNotFound if configuration.blank?

    configuration.slack_workspace_connection.slack_client.chat_postMessage(
      channel: configuration.channel_id,
      text: "Slack notifications are connected for #{@inbox.name}.",
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: ":white_check_mark: *Slack notifications are connected*\nInbox: *#{@inbox.name}*"
          }
        }
      ]
    )
    head :no_content
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def configuration_params
    params.require(:configuration).permit(
      :enabled,
      :slack_workspace_connection_id,
      :channel_id,
      :channel_name,
      rules: {}
    )
  end

  def configuration_payload(configuration)
    return { configuration: nil, default_rules: SlackInboxConfiguration::DEFAULT_RULES } if configuration.blank?

    {
      configuration: {
        id: configuration.id,
        enabled: configuration.enabled,
        slack_workspace_connection_id: configuration.slack_workspace_connection_id,
        channel_id: configuration.channel_id,
        channel_name: configuration.channel_name,
        rules: configuration.rules,
        last_delivered_at: configuration.last_delivered_at,
        last_error: configuration.last_error
      },
      default_rules: SlackInboxConfiguration::DEFAULT_RULES
    }
  end
end
