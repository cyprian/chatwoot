/* global axios */

import ApiClient from '../ApiClient';

class FirebaseProfileAPI extends ApiClient {
  constructor() {
    super('integrations/firebase_profile', { accountScoped: true });
  }

  getProfile(conversationId, contactId) {
    return axios.get(`${this.url}/show`, {
      params: { conversation_id: conversationId, contact_id: contactId },
    });
  }
}

export default new FirebaseProfileAPI();
