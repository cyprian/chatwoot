class Api::V1::Accounts::Integrations::EyePhotoController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation
  before_action :fetch_contact
  before_action :ensure_integration_enabled

  def show
    return render json: { error: 'Contact email is required' }, status: :unprocessable_entity if @contact.email.blank?

    render json: EyePhotoClient.new.lookup(email: @contact.email, api_key: @hook.access_token)
  rescue EyePhotoClient::UnavailableError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def fetch_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
    authorize @conversation, :show?
  end

  def fetch_contact
    @contact = Current.account.contacts.find(params[:contact_id])
    return if @conversation.contact_id == @contact.id

    render json: { error: 'Contact does not belong to this conversation' }, status: :unprocessable_entity
  end

  def ensure_integration_enabled
    @hook = Current.account.hooks.enabled.find_by!(app_id: 'eye_photo', inbox_id: @conversation.inbox_id)
  end
end
