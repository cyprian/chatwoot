/* global axios */

import ApiClient from '../ApiClient';

class EyePhotoAPI extends ApiClient {
  constructor() {
    super('integrations/eye_photo', { accountScoped: true });
  }

  getStudios(conversationId, contactId) {
    return axios.get(`${this.url}/show`, {
      params: { conversation_id: conversationId, contact_id: contactId },
    });
  }
}

export default new EyePhotoAPI();
