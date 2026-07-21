/* global axios */

const accountBaseUrl = accountId => `/api/v1/accounts/${accountId}`;

export default {
  connections(accountId) {
    return axios.get(
      `${accountBaseUrl(accountId)}/slack_workspace_connections`
    );
  },

  createConnection(accountId, inboxId, connection) {
    return axios.post(
      `${accountBaseUrl(accountId)}/slack_workspace_connections`,
      {
        inbox_id: inboxId,
        connection,
      }
    );
  },

  deleteConnection(accountId, connectionId) {
    return axios.delete(
      `${accountBaseUrl(accountId)}/slack_workspace_connections/${connectionId}`
    );
  },

  channels(accountId, connectionId) {
    return axios.get(
      `${accountBaseUrl(accountId)}/slack_workspace_connections/${connectionId}/channels`
    );
  },

  configuration(accountId, inboxId) {
    return axios.get(
      `${accountBaseUrl(accountId)}/inboxes/${inboxId}/slack_configuration`
    );
  },

  updateConfiguration(accountId, inboxId, configuration) {
    return axios.patch(
      `${accountBaseUrl(accountId)}/inboxes/${inboxId}/slack_configuration`,
      { configuration }
    );
  },

  testConfiguration(accountId, inboxId) {
    return axios.post(
      `${accountBaseUrl(accountId)}/inboxes/${inboxId}/slack_configuration/test`
    );
  },
};
