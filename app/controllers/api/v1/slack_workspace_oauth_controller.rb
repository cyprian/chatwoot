class Api::V1::SlackWorkspaceOauthController < ApplicationController
  def callback
    state = Rails.application.message_verifier(:slack_workspace_oauth).verify(params.require(:state)).with_indifferent_access
    connection = SlackWorkspaceConnection.find(state.fetch(:connection_id))
    raise ActiveRecord::RecordNotFound unless connection.account_id == state.fetch(:account_id)

    connection.connect!(params.require(:code))
    redirect_to inbox_settings_url(state, 'connected'), allow_other_host: true
  rescue StandardError => e
    connection&.update(last_error: e.message, status: :disconnected)
    redirect_to inbox_settings_url(state || {}, 'error'), allow_other_host: true
  end

  private

  def inbox_settings_url(state, result)
    account_id = state[:account_id]
    inbox_id = state[:inbox_id]
    return "#{ENV.fetch('FRONTEND_URL')}/app?slack_oauth=#{result}" if account_id.blank? || inbox_id.blank?

    "#{ENV.fetch('FRONTEND_URL')}/app/accounts/#{account_id}/settings/inboxes/#{inbox_id}/slack-notifications?slack_oauth=#{result}"
  end
end
