<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SlackNotificationsAPI from 'dashboard/api/slackNotifications';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const route = useRoute();
const { t } = useI18n();
const accountId = computed(() => route.params.accountId);
const inboxId = computed(() => props.inbox.id);
const callbackUrl = `${window.location.origin}/api/v1/slack_workspace_oauth/callback`;

const isLoading = ref(true);
const isSaving = ref(false);
const isConnecting = ref(false);
const isLoadingChannels = ref(false);
const isTesting = ref(false);
const deletingConnectionId = ref(null);
const connections = ref([]);
const channels = ref([]);
const defaultRules = ref({});

const connectionForm = reactive({
  name: '',
  client_id: '',
  client_secret: '',
});

const form = reactive({
  enabled: false,
  slack_workspace_connection_id: '',
  channel_id: '',
  channel_name: '',
  rules: {},
});

const eventOptions = computed(() => [
  {
    key: 'conversation_created',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.CONVERSATION_CREATED'),
  },
  {
    key: 'incoming_message',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.INCOMING_MESSAGE'),
  },
  {
    key: 'outgoing_message',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.OUTGOING_MESSAGE'),
  },
  {
    key: 'private_note',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.PRIVATE_NOTE'),
  },
  {
    key: 'assignment_changed',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.ASSIGNMENT_CHANGED'),
  },
  {
    key: 'status_changed',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENT.STATUS_CHANGED'),
  },
]);

const contentOptions = computed(() => [
  {
    key: 'sender_name',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.SENDER_NAME'),
  },
  {
    key: 'sender_email',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.SENDER_EMAIL'),
  },
  { key: 'subject', label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.SUBJECT') },
  {
    key: 'attachments',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.ATTACHMENTS'),
  },
  {
    key: 'assignee',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.ASSIGNEE'),
  },
  { key: 'labels', label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.LABELS') },
  {
    key: 'priority',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.PRIORITY'),
  },
  {
    key: 'inbox_name',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.INBOX_NAME'),
  },
  {
    key: 'conversation_link',
    label: t('INBOX_MGMT.SLACK_NOTIFICATIONS.FIELD.CONVERSATION_LINK'),
  },
]);

const selectedChannel = computed(() =>
  channels.value.find(channel => channel.id === form.channel_id)
);

const connectedWorkspaces = computed(() =>
  connections.value.filter(connection => connection.status === 'connected')
);

const clone = value => JSON.parse(JSON.stringify(value || {}));
const errorMessage = error =>
  error.response?.data?.error || error.response?.data?.message || error.message;

const workspaceOption = connection =>
  t('INBOX_MGMT.SLACK_NOTIFICATIONS.WORKSPACE_OPTION', {
    name: connection.name,
    workspace: connection.slack_team_name,
  });

const channelOption = channel =>
  t('INBOX_MGMT.SLACK_NOTIFICATIONS.CHANNEL_OPTION', {
    name: channel.name,
    private: channel.private
      ? t('INBOX_MGMT.SLACK_NOTIFICATIONS.PRIVATE_SUFFIX')
      : '',
  });

const loadChannels = async connectionId => {
  channels.value = [];
  if (!connectionId) return;

  isLoadingChannels.value = true;
  try {
    const response = await SlackNotificationsAPI.channels(
      accountId.value,
      connectionId
    );
    channels.value = response.data;
    if (
      form.channel_id &&
      !channels.value.some(channel => channel.id === form.channel_id)
    ) {
      channels.value.unshift({
        id: form.channel_id,
        name: form.channel_name,
        private: false,
      });
    }
  } catch (error) {
    useAlert(errorMessage(error) || t('INBOX_MGMT.SLACK_NOTIFICATIONS.ERROR'));
  } finally {
    isLoadingChannels.value = false;
  }
};

const load = async () => {
  isLoading.value = true;
  try {
    const [connectionsResponse, configurationResponse] = await Promise.all([
      SlackNotificationsAPI.connections(accountId.value),
      SlackNotificationsAPI.configuration(accountId.value, inboxId.value),
    ]);
    connections.value = connectionsResponse.data;
    defaultRules.value = configurationResponse.data.default_rules;
    const configuration = configurationResponse.data.configuration;
    if (configuration) {
      Object.assign(form, configuration, { rules: clone(configuration.rules) });
      await loadChannels(form.slack_workspace_connection_id);
    } else {
      form.rules = clone(defaultRules.value);
    }
  } catch (error) {
    useAlert(errorMessage(error) || t('INBOX_MGMT.SLACK_NOTIFICATIONS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const connectWorkspace = async () => {
  isConnecting.value = true;
  try {
    const response = await SlackNotificationsAPI.createConnection(
      accountId.value,
      inboxId.value,
      connectionForm
    );
    window.location.assign(response.data.authorization_url);
  } catch (error) {
    useAlert(errorMessage(error) || t('INBOX_MGMT.SLACK_NOTIFICATIONS.ERROR'));
    isConnecting.value = false;
  }
};

const removeConnection = async connection => {
  deletingConnectionId.value = connection.id;
  try {
    await SlackNotificationsAPI.deleteConnection(
      accountId.value,
      connection.id
    );
    connections.value = connections.value.filter(
      item => item.id !== connection.id
    );
    if (form.slack_workspace_connection_id === connection.id) {
      form.slack_workspace_connection_id = '';
      form.channel_id = '';
      form.channel_name = '';
    }
    useAlert(t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECTION_REMOVED'));
  } catch (error) {
    useAlert(
      errorMessage(error) ||
        t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECTION_IN_USE')
    );
  } finally {
    deletingConnectionId.value = null;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    form.channel_name = selectedChannel.value?.name || form.channel_name;
    const response = await SlackNotificationsAPI.updateConfiguration(
      accountId.value,
      inboxId.value,
      form
    );
    Object.assign(form, response.data.configuration, {
      rules: clone(response.data.configuration.rules),
    });
    useAlert(t('INBOX_MGMT.SLACK_NOTIFICATIONS.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error) || t('INBOX_MGMT.SLACK_NOTIFICATIONS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const sendTest = async () => {
  isTesting.value = true;
  try {
    await SlackNotificationsAPI.testConfiguration(
      accountId.value,
      inboxId.value
    );
    useAlert(t('INBOX_MGMT.SLACK_NOTIFICATIONS.TEST_SENT'));
  } catch (error) {
    useAlert(errorMessage(error) || t('INBOX_MGMT.SLACK_NOTIFICATIONS.ERROR'));
  } finally {
    isTesting.value = false;
  }
};

watch(
  () => form.slack_workspace_connection_id,
  async (connectionId, previousConnectionId) => {
    if (previousConnectionId && connectionId !== previousConnectionId) {
      form.channel_id = '';
      form.channel_name = '';
    }
    await loadChannels(connectionId);
  }
);

onMounted(async () => {
  await load();
  if (route.query.slack_oauth === 'connected') {
    useAlert(t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECTION_SUCCESS'));
  } else if (route.query.slack_oauth === 'error') {
    useAlert(t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECTION_ERROR'));
  }
});
</script>

<template>
  <div class="space-y-6 pb-10">
    <div>
      <h2 class="text-heading-1 text-n-slate-12">
        {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.TITLE') }}
      </h2>
      <p class="mt-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.DESCRIPTION') }}
      </p>
    </div>

    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <template v-else>
      <section
        class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 p-5"
      >
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECT_APP') }}
        </h3>
        <p class="mt-1 text-body-small text-n-slate-11">
          {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECT_HELP') }}
        </p>
        <div
          class="mt-3 rounded-lg bg-n-alpha-2 px-3 py-2 text-body-small text-n-slate-11 break-all"
        >
          {{ callbackUrl }}
        </div>
        <div class="mt-4 grid gap-4 md:grid-cols-3">
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.APP_NAME') }}</span>
            <input
              v-model="connectionForm.name"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            />
          </label>
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CLIENT_ID') }}</span>
            <input
              v-model="connectionForm.client_id"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            />
          </label>
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CLIENT_SECRET') }}</span>
            <input
              v-model="connectionForm.client_secret"
              type="password"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            />
          </label>
        </div>
        <Button
          class="mt-4"
          :label="t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONNECT')"
          :is-loading="isConnecting"
          :disabled="
            !connectionForm.name ||
            !connectionForm.client_id ||
            !connectionForm.client_secret
          "
          @click="connectWorkspace"
        />
        <div
          v-if="connections.length"
          class="mt-5 border-t border-n-weak pt-4 space-y-2"
        >
          <div
            v-for="connection in connections"
            :key="connection.id"
            class="flex items-center justify-between gap-4 rounded-lg bg-n-alpha-1 px-3 py-2"
          >
            <div>
              <p class="text-body-main text-n-slate-12">
                {{ connection.name }}
              </p>
              <p class="text-body-small text-n-slate-11">
                {{ connection.slack_team_name || connection.status }}
              </p>
            </div>
            <Button
              ruby
              outline
              size="sm"
              :label="t('INBOX_MGMT.SLACK_NOTIFICATIONS.REMOVE_CONNECTION')"
              :is-loading="deletingConnectionId === connection.id"
              @click="removeConnection(connection)"
            />
          </div>
        </div>
      </section>

      <section
        class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 p-5 space-y-5"
      >
        <label
          class="flex items-center justify-between gap-4 text-body-main text-n-slate-12"
        >
          <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.ENABLED') }}</span>
          <input
            v-model="form.enabled"
            type="checkbox"
            class="h-5 w-5 rounded border-n-weak"
          />
        </label>

        <div class="grid gap-4 md:grid-cols-2">
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.WORKSPACE') }}</span>
            <select
              v-model="form.slack_workspace_connection_id"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            >
              <option value="">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.SELECT_WORKSPACE') }}
              </option>
              <option
                v-for="connection in connectedWorkspaces"
                :key="connection.id"
                :value="connection.id"
              >
                {{ workspaceOption(connection) }}
              </option>
            </select>
          </label>
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CHANNEL') }}</span>
            <select
              v-model="form.channel_id"
              :disabled="
                isLoadingChannels || !form.slack_workspace_connection_id
              "
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            >
              <option value="">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.SELECT_CHANNEL') }}
              </option>
              <option
                v-for="channel in channels"
                :key="channel.id"
                :value="channel.id"
              >
                {{ channelOption(channel) }}
              </option>
            </select>
          </label>
        </div>
      </section>

      <section
        v-if="form.rules.events"
        class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 p-5"
      >
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.EVENTS') }}
        </h3>
        <div class="mt-4 grid gap-3 md:grid-cols-2">
          <label
            v-for="event in eventOptions"
            :key="event.key"
            class="flex items-center gap-3 text-body-main text-n-slate-12"
          >
            <input
              v-model="form.rules.events[event.key]"
              type="checkbox"
              class="h-4 w-4 rounded border-n-weak"
            />
            <span>{{ event.label }}</span>
          </label>
        </div>
      </section>

      <section
        v-if="form.rules.content"
        class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 p-5 space-y-5"
      >
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONTENT') }}
        </h3>
        <div class="grid gap-3 md:grid-cols-2">
          <label
            v-for="field in contentOptions"
            :key="field.key"
            class="flex items-center gap-3 text-body-main text-n-slate-12"
          >
            <input
              v-model="form.rules.content[field.key]"
              type="checkbox"
              class="h-4 w-4 rounded border-n-weak"
            />
            <span>{{ field.label }}</span>
          </label>
        </div>
        <div class="grid gap-4 md:grid-cols-2">
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.BODY') }}</span>
            <select
              v-model="form.rules.content.body"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            >
              <option value="none">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.BODY_NONE') }}
              </option>
              <option value="preview">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.BODY_PREVIEW') }}
              </option>
              <option value="full">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.BODY_FULL') }}
              </option>
            </select>
          </label>
          <label
            v-if="form.rules.content.body === 'preview'"
            class="space-y-1 text-body-small text-n-slate-12"
          >
            <span>{{
              t('INBOX_MGMT.SLACK_NOTIFICATIONS.PREVIEW_LENGTH')
            }}</span>
            <input
              v-model.number="form.rules.content.body_preview_length"
              type="number"
              min="100"
              max="2500"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            />
          </label>
        </div>
        <label class="flex items-center gap-3 text-body-main text-n-slate-12">
          <input
            v-model="form.rules.thread_updates"
            type="checkbox"
            class="h-4 w-4 rounded border-n-weak"
          />
          <span>{{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.THREAD_UPDATES') }}</span>
        </label>
      </section>

      <section
        v-if="form.rules.conditions"
        class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 p-5 space-y-4"
      >
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.CONDITIONS') }}
        </h3>
        <div class="grid gap-4 md:grid-cols-3">
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{
              t('INBOX_MGMT.SLACK_NOTIFICATIONS.MINIMUM_PRIORITY')
            }}</span>
            <select
              v-model="form.rules.conditions.minimum_priority"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
            >
              <option :value="null">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.ANY_PRIORITY') }}
              </option>
              <option value="low">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.PRIORITY_LOW') }}
              </option>
              <option value="medium">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.PRIORITY_MEDIUM') }}
              </option>
              <option value="high">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.PRIORITY_HIGH') }}
              </option>
              <option value="urgent">
                {{ t('INBOX_MGMT.SLACK_NOTIFICATIONS.PRIORITY_URGENT') }}
              </option>
            </select>
          </label>
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{
              t('INBOX_MGMT.SLACK_NOTIFICATIONS.INCLUDE_LABELS')
            }}</span>
            <input
              :value="form.rules.conditions.include_labels.join(', ')"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
              @input="
                form.rules.conditions.include_labels = $event.target.value
                  .split(',')
                  .map(value => value.trim())
                  .filter(Boolean)
              "
            />
          </label>
          <label class="space-y-1 text-body-small text-n-slate-12">
            <span>{{
              t('INBOX_MGMT.SLACK_NOTIFICATIONS.EXCLUDE_LABELS')
            }}</span>
            <input
              :value="form.rules.conditions.exclude_labels.join(', ')"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
              @input="
                form.rules.conditions.exclude_labels = $event.target.value
                  .split(',')
                  .map(value => value.trim())
                  .filter(Boolean)
              "
            />
          </label>
        </div>
      </section>

      <div
        v-if="form.last_error"
        class="rounded-lg bg-n-ruby-3 p-3 text-body-small text-n-ruby-11"
      >
        {{ form.last_error }}
      </div>

      <div class="flex justify-end gap-3">
        <Button
          outline
          :label="t('INBOX_MGMT.SLACK_NOTIFICATIONS.TEST')"
          :is-loading="isTesting"
          :disabled="!form.id"
          @click="sendTest"
        />
        <Button
          :label="t('INBOX_MGMT.SLACK_NOTIFICATIONS.SAVE')"
          :is-loading="isSaving"
          :disabled="!form.slack_workspace_connection_id || !form.channel_id"
          @click="save"
        />
      </div>
    </template>
  </div>
</template>
