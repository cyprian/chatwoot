class Api::V1::Accounts::Integrations::FirebaseProfileController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation
  before_action :fetch_contact
  before_action :ensure_integration_enabled

  def show
    return render json: { error: 'Contact email is required' }, status: :unprocessable_entity if @contact.email.blank?

    response = FirebaseProfileGateway.new.lookup(@contact.email)
    render json: response
  rescue FirebaseProfileGateway::UnavailableError => e
    render json: { error: e.message }, status: :service_unavailable
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
    Current.account.hooks.enabled.find_by!(app_id: 'firebase_profile', inbox_id: @conversation.inbox_id)
  end
end
