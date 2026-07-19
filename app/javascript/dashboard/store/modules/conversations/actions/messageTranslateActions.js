import MessageApi from '../../../../api/inbox/message';

export default {
  async translateMessage({ commit }, { conversationId, messageId }) {
    const { data } = await MessageApi.translateMessage(
      conversationId,
      messageId
    );
    commit('ADD_MESSAGE', data);
    return data;
  },
};
