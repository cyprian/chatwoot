<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import EyePhotoAPI from 'dashboard/api/integrations/eyePhoto';
import ContactAPI from 'dashboard/api/contacts';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contactId: { type: [Number, String], required: true },
  email: { type: String, default: '' },
});

const data = ref(null);
const loading = ref(false);
const error = ref('');
const showUsers = ref(false);
const selectedStudio = ref(null);
const chatwootContactIds = ref({});
const composeConversationRefs = ref({});
const preparingConversationFor = ref('');
const store = useStore();
let latestRequestId = 0;

const studios = computed(() => data.value?.studios || []);
const studioPhotos = studio =>
  Number(studio.photos_count || 0).toLocaleString();
const selectedUsers = computed(() => selectedStudio.value?.users || []);
const studioAdminUrl = studio =>
  `https://eye.photo/admin/studios/${studio.id}/login`;

const openUsers = studio => {
  selectedStudio.value = studio;
  showUsers.value = true;
};

const emailKey = email => email.toLowerCase();

const setComposeConversationRef = (email, component) => {
  const key = emailKey(email);
  if (component) composeConversationRefs.value[key] = component;
  else delete composeConversationRefs.value[key];
};

const prepareConversation = async user => {
  const key = emailKey(user.email);
  if (chatwootContactIds.value[key]) return;

  preparingConversationFor.value = key;
  try {
    const {
      data: { payload = [] },
    } = await ContactAPI.search(user.email, 1, 'name');
    const contact =
      payload.find(
        candidate => emailKey(candidate.email || '') === emailKey(user.email)
      ) ||
      (await store.dispatch('contacts/create', {
        name: user.name || user.email.split('@')[0],
        email: user.email,
      }));

    await store.dispatch('contacts/setContact', contact);
    await store.dispatch('contacts/fetchContactableInbox', contact.id);
    chatwootContactIds.value = {
      ...chatwootContactIds.value,
      [key]: contact.id,
    };
    await nextTick();
    composeConversationRefs.value[key]?.openCompose();
  } catch (requestError) {
    useAlert('Unable to prepare a Chatwoot conversation.');
  } finally {
    if (preparingConversationFor.value === key) {
      preparingConversationFor.value = '';
    }
  }
};

const loadStudios = async () => {
  latestRequestId += 1;
  const requestId = latestRequestId;
  data.value = null;
  error.value = '';
  selectedStudio.value = null;
  showUsers.value = false;

  if (!props.email) {
    loading.value = false;
    return;
  }

  loading.value = true;
  try {
    const { data: response } = await EyePhotoAPI.getStudios(
      props.conversationId,
      props.contactId
    );
    if (requestId === latestRequestId) data.value = response;
  } catch (requestError) {
    if (requestId === latestRequestId) {
      error.value =
        requestError.response?.data?.error || 'Unable to load Eye.photo data.';
    }
  } finally {
    if (requestId === latestRequestId) loading.value = false;
  }
};

watch(() => [props.conversationId, props.contactId, props.email], loadStudios, {
  immediate: true,
});
</script>

<template>
  <div class="px-4 py-3 text-sm text-n-slate-12">
    <div class="mb-3 flex items-center justify-between gap-3">
      <span />
      <button
        v-if="email"
        class="rounded px-2 py-1 text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:cursor-not-allowed disabled:opacity-60"
        :disabled="loading"
        type="button"
        @click="loadStudios"
      >
        {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.REFRESH') }}
      </button>
    </div>

    <p v-if="!email" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.NO_EMAIL') }}
    </p>
    <p v-else-if="loading && !data" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.LOADING') }}
    </p>
    <p v-else-if="error" class="text-n-ruby-11">{{ error }}</p>
    <p v-else-if="!studios.length" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.NOT_FOUND') }}
    </p>

    <div v-else class="space-y-3">
      <article
        v-for="studio in studios"
        :key="studio.id"
        class="overflow-hidden rounded-lg border border-n-weak bg-n-alpha-1"
      >
        <div class="space-y-3 p-3">
          <div>
            <p class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.STUDIO') }}:
            </p>
            <p class="mt-0.5 truncate font-semibold">
              {{ studio.name || '—' }}
            </p>
          </div>
          <div>
            <p class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.STATUS') }}:
            </p>
            <p class="mt-0.5 capitalize">{{ studio.status || '—' }}</p>
          </div>
          <div>
            <p class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.PLAN') }}:
            </p>
            <p class="mt-0.5">{{ studio.plan?.name || '—' }}</p>
          </div>
        </div>

        <div class="space-y-2 border-t border-n-weak bg-n-alpha-2 px-3 py-2">
          <div class="flex items-center justify-between gap-3">
            <span class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.PHOTOS') }}:
            </span>
            <span class="font-semibold">{{ studioPhotos(studio) }}</span>
          </div>
          <div class="flex items-center justify-between gap-3">
            <span class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.USERS') }}:
            </span>
            <span class="font-semibold">{{ studio.users?.length || 0 }}</span>
          </div>
        </div>

        <div class="flex gap-2 border-t border-n-weak p-3">
          <button
            class="flex-1 rounded border border-n-weak px-3 py-2 text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:cursor-not-allowed disabled:opacity-60"
            :disabled="!studio.users?.length"
            type="button"
            @click="openUsers(studio)"
          >
            {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.SHOW_USERS') }}
          </button>
          <a
            :href="studioAdminUrl(studio)"
            class="flex-1 rounded bg-n-brand px-3 py-2 text-center text-xs font-medium text-white hover:bg-n-brand/90"
            rel="noopener noreferrer"
            target="_blank"
          >
            {{ $t('CONVERSATION_SIDEBAR.EYE_PHOTO.VIEW_IN_EYE_PHOTO') }}
          </a>
        </div>
      </article>
    </div>

    <woot-modal
      v-model:show="showUsers"
      :on-close="() => (showUsers = false)"
      size="modal-small"
    >
      <woot-modal-header
        :header-title="`${$t('CONVERSATION_SIDEBAR.EYE_PHOTO.USERS')} · ${selectedStudio?.name || ''}`"
      />
      <div class="max-h-[60vh] space-y-2 overflow-y-auto px-6 pb-6">
        <div
          v-for="user in selectedUsers"
          :key="user.email"
          class="flex items-center justify-between gap-3 rounded-lg border border-n-weak p-3"
        >
          <div class="min-w-0">
            <p class="truncate font-medium">{{ user.name || '—' }}</p>
            <p class="truncate text-xs text-n-slate-11">{{ user.email }}</p>
          </div>
          <ComposeConversation
            v-if="chatwootContactIds[emailKey(user.email)]"
            :ref="component => setComposeConversationRef(user.email, component)"
            :contact-id="String(chatwootContactIds[emailKey(user.email)])"
          >
            <template #trigger>
              <button
                :aria-label="
                  $t('CONVERSATION_SIDEBAR.EYE_PHOTO.START_CONVERSATION', {
                    name: user.name || user.email,
                  })
                "
                class="rounded p-2 text-n-brand hover:bg-n-alpha-2"
                type="button"
              >
                <fluent-icon icon="chat" size="18" />
              </button>
            </template>
          </ComposeConversation>
          <button
            v-else
            :aria-label="
              $t('CONVERSATION_SIDEBAR.EYE_PHOTO.START_CONVERSATION', {
                name: user.name || user.email,
              })
            "
            class="rounded p-2 text-n-brand hover:bg-n-alpha-2 disabled:cursor-not-allowed disabled:opacity-60"
            :disabled="preparingConversationFor === emailKey(user.email)"
            type="button"
            @click="prepareConversation(user)"
          >
            <fluent-icon icon="chat" size="18" />
          </button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>
