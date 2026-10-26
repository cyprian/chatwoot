import { computed, ref, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

export function useEnglishTranslation({
  id,
  conversationId,
  contentAttributes,
  showingOriginal,
}) {
  const store = useStore();
  const isTranslating = ref(false);
  const englishTranslation = computed(
    () => contentAttributes.value?.translations?.en
  );
  const hasEnglishTranslation = computed(() => !!englishTranslation.value);

  const showEnglishTranslation = event => {
    if (Number(event.detail?.messageId) === Number(id.value)) {
      showingOriginal.value = false;
    }
  };
  onMounted(() =>
    window.addEventListener(
      'chatwoot:show-english-translation',
      showEnglishTranslation
    )
  );
  onBeforeUnmount(() =>
    window.removeEventListener(
      'chatwoot:show-english-translation',
      showEnglishTranslation
    )
  );

  const translateToEnglish = async () => {
    isTranslating.value = true;
    try {
      await store.dispatch('translateMessage', {
        conversationId: conversationId.value,
        messageId: id.value,
      });
      showingOriginal.value = false;
    } catch (error) {
      useAlert(parseAPIErrorResponse(error));
    } finally {
      isTranslating.value = false;
    }
  };

  return {
    englishTranslation,
    hasEnglishTranslation,
    isTranslating,
    translateToEnglish,
  };
}
