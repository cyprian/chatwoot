require 'rails_helper'

RSpec.describe Api::V1::Accounts::Integrations::HooksController, type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  it 'stores the Eye.photo API key in the hook token instead of JSON settings' do
    post api_v1_account_integrations_hooks_url(account_id: account.id),
         params: { app_id: 'eye_photo', inbox_id: inbox.id, settings: { api_key: 'eye-photo-admin-key' } },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    hook = account.hooks.find_by!(app_id: 'eye_photo', inbox_id: inbox.id)
    expect(hook.access_token).to eq('eye-photo-admin-key')
    expect(hook.settings).to eq({})
    expect(response.parsed_body.dig('settings', 'api_key')).to be_nil
  end

  it 'does not allow a second Eye.photo key for the same inbox' do
    create(:integrations_hook, account: account, inbox: inbox, app_id: 'eye_photo', settings: {})

    post api_v1_account_integrations_hooks_url(account_id: account.id),
         params: { app_id: 'eye_photo', inbox_id: inbox.id, settings: { api_key: 'another-key' } },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
