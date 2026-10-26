import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import EmailBubble from '../Index.vue';
import { provideMessageContext } from '../../../provider.js';
import { MESSAGE_TYPES } from '../../../constants';

vi.mock('dashboard/composables/useTranslations', async () => {
  const { ref: makeRef } = await import('vue');
  return {
    useTranslations: () => ({
      hasTranslations: makeRef(false),
      translationContent: makeRef(''),
    }),
  };
});

const store = { dispatch: vi.fn().mockResolvedValue({}) };

const html = '<p>Latest reply</p><div class="gmail_quote">Older reply</div>';

const mountBubble = (
  contentAttributes,
  messageType = MESSAGE_TYPES.OUTGOING
) => {
  const Host = defineComponent({
    components: { EmailBubble },
    setup() {
      provideMessageContext({
        id: ref(99),
        conversationId: ref(12),
        content: ref('Latest reply'),
        contentAttributes: ref({
          email: {
            htmlContent: { full: html },
            textContent: { full: 'Latest reply' },
          },
          ...contentAttributes,
        }),
        attachments: ref([]),
        messageType: ref(messageType),
        showingOriginal: ref(false),
      });
    },
    template: '<EmailBubble />',
  });

  return mount(Host, {
    global: {
      provide: { store },
      mocks: { $store: { getters: { getSelectedChatAttachments: [] } } },
      stubs: {
        BaseBubble: { template: '<div><slot /></div>' },
        EmailMeta: true,
        AttachmentChips: true,
        TranslationToggle: true,
        Icon: true,
      },
    },
  });
};

describe('Email bubble', () => {
  it('collapses quoted history behind the toggle for regular emails', () => {
    const wrapper = mountBubble({});
    const letter = wrapper.find('.letter-render');

    expect(letter.text()).toContain('Latest reply');
    expect(letter.text()).not.toContain('Older reply');
    expect(wrapper.text()).toContain('CHAT_LIST.SHOW_QUOTED_TEXT');
  });

  it('shows the full body for a forwarded email', () => {
    const wrapper = mountBubble({ forwardedMessageId: 501 });
    const letter = wrapper.find('.letter-render');

    expect(letter.text()).toContain('Latest reply');
    expect(letter.text()).toContain('Older reply');
    expect(wrapper.text()).not.toContain('CHAT_LIST.SHOW_QUOTED_TEXT');
  });

  it('escapes English translations and lets the agent return to the original email', async () => {
    const wrapper = mountBubble({
      translations: { en: 'Hello <script>alert(1)</script>\nThanks' },
    });
    expect(wrapper.find('.letter-render').text()).toContain(
      'Hello <script>alert(1)</script>'
    );
    expect(wrapper.find('.letter-render script').exists()).toBe(false);
    const originalButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('CONVERSATION.VIEW_ORIGINAL'));
    await originalButton.trigger('click');
    expect(wrapper.find('.letter-render').text()).toContain('Latest reply');
    window.dispatchEvent(
      new CustomEvent('chatwoot:show-english-translation', {
        detail: { messageId: 99 },
      })
    );
    await wrapper.vm.$nextTick();
    expect(wrapper.find('.letter-render').text()).toContain(
      'Hello <script>alert(1)</script>'
    );
    wrapper.unmount();
  });

  it('uses the custom English action for incoming emails', async () => {
    const wrapper = mountBubble({}, MESSAGE_TYPES.INCOMING);
    const translateButton = wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('CONVERSATION.TRANSLATE_TO_ENGLISH')
      );
    await translateButton.trigger('click');
    expect(store.dispatch).toHaveBeenCalledWith('translateMessage', {
      conversationId: 12,
      messageId: 99,
    });
    wrapper.unmount();
  });
});
