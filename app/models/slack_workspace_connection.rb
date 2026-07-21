class SlackWorkspaceConnection < ApplicationRecord
  encrypts :client_secret if Chatwoot.encryption_configured?
  encrypts :access_token if Chatwoot.encryption_configured?

  belongs_to :account
  has_many :slack_inbox_configurations, dependent: :restrict_with_error

  enum status: { pending: 0, connected: 1, disconnected: 2 }

  validates :name, :client_id, :client_secret, presence: true
  validates :access_token, :slack_team_id, :slack_team_name, presence: true, if: :connected?

  def callback_url
    "#{ENV.fetch('FRONTEND_URL')}/api/v1/slack_workspace_oauth/callback"
  end

  def authorization_url(inbox_id:)
    query = URI.encode_www_form(
      client_id: client_id,
      scope: 'chat:write,chat:write.public,channels:read,groups:read',
      redirect_uri: callback_url,
      state: oauth_state(inbox_id: inbox_id)
    )
    "https://slack.com/oauth/v2/authorize?#{query}"
  end

  def oauth_state(inbox_id:)
    Rails.application.message_verifier(:slack_workspace_oauth).generate(
      { connection_id: id, account_id: account_id, inbox_id: inbox_id },
      expires_in: 15.minutes
    )
  end

  def connect!(code)
    response = Slack::Web::Client.new.oauth_v2_access(
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: callback_url
    )

    update!(
      access_token: response.fetch('access_token'),
      slack_team_id: response.dig('team', 'id'),
      slack_team_name: response.dig('team', 'name'),
      slack_bot_user_id: response.fetch('bot_user_id'),
      status: :connected,
      last_error: nil
    )
  end

  def slack_client
    Slack::Web::Client.new(token: access_token)
  end
end
