class Api::V1::Accounts::SlackWorkspaceConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection, only: [:destroy, :channels]

  def index
    render json: Current.account.slack_workspace_connections.order(:name).map { |connection| connection_payload(connection) }
  end

  def create
    connection = Current.account.slack_workspace_connections.create!(connection_params)
    inbox = Current.account.inboxes.find(params.require(:inbox_id))

    render json: connection_payload(connection).merge(authorization_url: connection.authorization_url(inbox_id: inbox.id)),
           status: :created
  end

  def destroy
    if @connection.destroy
      head :no_content
    else
      render json: { error: @connection.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def channels
    channels = fetch_channels(@connection.slack_client)
    render json: channels.map { |channel| { id: channel.id, name: channel.name, private: channel.is_private } }
  end

  private

  def fetch_connection
    @connection = Current.account.slack_workspace_connections.find(params[:id])
  end

  def connection_params
    params.require(:connection).permit(:name, :client_id, :client_secret)
  end

  def connection_payload(connection)
    {
      id: connection.id,
      name: connection.name,
      client_id: connection.client_id,
      status: connection.status,
      slack_team_id: connection.slack_team_id,
      slack_team_name: connection.slack_team_name,
      last_error: connection.last_error
    }
  end

  def fetch_channels(client)
    response = client.conversations_list(types: 'public_channel,private_channel', exclude_archived: true, limit: 200)
    channels = response.channels
    while response.response_metadata.next_cursor.present?
      response = client.conversations_list(
        types: 'public_channel,private_channel',
        exclude_archived: true,
        limit: 200,
        cursor: response.response_metadata.next_cursor
      )
      channels.concat(response.channels)
    end
    channels.sort_by { |channel| channel.name.downcase }
  end
end
