require 'rails_helper'

RSpec.describe 'Firebase Profile Integration API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, email: 'customer@example.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:gateway) { instance_double(FirebaseProfileGateway) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:integrations_hook, account: account, inbox: inbox, app_id: 'firebase_profile')
    allow(FirebaseProfileGateway).to receive(:new).and_return(gateway)
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/firebase_profile/show' do
    it 'returns the Firebase profile for a contact in an enabled inbox' do
      allow(gateway).to receive(:lookup).with(contact.email).and_return({ 'auth' => { 'found' => true, 'uid' => 'uid-1' } })

      get "/api/v1/accounts/#{account.id}/integrations/firebase_profile/show",
          params: { conversation_id: conversation.id, contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('auth', 'uid')).to eq('uid-1')
    end

    it 'does not expose the integration from an inbox without its hook' do
      other_inbox = create(:inbox, account: account)
      create(:inbox_member, inbox: other_inbox, user: agent)
      other_conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)

      get "/api/v1/accounts/#{account.id}/integrations/firebase_profile/show",
          params: { conversation_id: other_conversation.id, contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/integrations/firebase_profile/show",
          params: { conversation_id: conversation.id, contact_id: contact.id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
