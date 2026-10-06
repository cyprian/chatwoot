require 'rails_helper'

RSpec.describe 'Eye.photo Integration API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, email: 'owner@example.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:client) { instance_double(EyePhotoClient) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:integrations_hook, account: account, inbox: inbox, app_id: 'eye_photo', access_token: 'admin-api-key', settings: {})
    allow(EyePhotoClient).to receive(:new).and_return(client)
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/eye_photo/show' do
    it 'returns studios associated with the conversation contact email' do
      payload = { 'email' => contact.email, 'studios' => [{ 'id' => 42, 'name' => 'Example Studio', 'photos_count' => 128 }] }
      allow(client).to receive(:lookup).with(email: contact.email, api_key: 'admin-api-key').and_return(payload)

      get "/api/v1/accounts/#{account.id}/integrations/eye_photo/show",
          params: { conversation_id: conversation.id, contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('studios', 0, 'name')).to eq('Example Studio')
    end

    it 'does not expose a key configured for another inbox' do
      other_inbox = create(:inbox, account: account)
      create(:inbox_member, inbox: other_inbox, user: agent)
      other_conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)

      get "/api/v1/accounts/#{account.id}/integrations/eye_photo/show",
          params: { conversation_id: other_conversation.id, contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns an unavailable response when Eye.photo cannot be reached' do
      allow(client).to receive(:lookup).and_raise(EyePhotoClient::UnavailableError, 'Eye.photo could not retrieve studio data')

      get "/api/v1/accounts/#{account.id}/integrations/eye_photo/show",
          params: { conversation_id: conversation.id, contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
