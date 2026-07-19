<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const { id, content, attachments, contentAttributes, conversationId, messageType } =
  useMessageContext();
const store = useStore();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);
const isTranslating = ref(false);
const englishTranslation = computed(
  () => contentAttributes.value?.translations?.en
);
const hasEnglishTranslation = computed(() => !!englishTranslation.value);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasEnglishTranslation.value) {
    return englishTranslation.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};

const shouldShowTranslateAction = computed(() => {
  return (
    messageType.value === MESSAGE_TYPES.INCOMING &&
    !hasEnglishTranslation.value
  );
});

const translateToEnglish = async () => {
  isTranslating.value = true;
  try {
    await store.dispatch('translateMessage', {
      conversationId: conversationId.value,
      messageId: id.value,
    });
  } catch (error) {
    useAlert(parseAPIErrorResponse(error));
  } finally {
    isTranslating.value = false;
  }
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <NextButton
        v-if="shouldShowTranslateAction"
        ghost
        slate
        xs
        icon="i-lucide-languages"
        :is-loading="isTranslating"
        class="self-start -ml-2 -mb-2"
        @click="translateToEnglish"
      >
        {{ $t('CONVERSATION.TRANSLATE_TO_ENGLISH') }}
      </NextButton>
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
