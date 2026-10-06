<script setup>
import { computed, onMounted, ref } from 'vue';
import FirebaseProfileAPI from 'dashboard/api/integrations/firebaseProfile';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contactId: { type: [Number, String], required: true },
  email: { type: String, default: '' },
});

const profile = ref(null);
const loading = ref(false);
const error = ref('');
const showTransactions = ref(false);
const transactionTitle = ref('');
const selectedTransactions = ref([]);

const credits = computed(() => profile.value?.credits?.data || {});
const subscription = computed(() => profile.value?.subscription?.data || {});
const creditTransactions = computed(() => credits.value.transactions || []);
const subscriptionTransactions = computed(
  () => subscription.value.transactions || []
);

const checkProfile = async () => {
  if (!props.email) return;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await FirebaseProfileAPI.getProfile(
      props.conversationId,
      props.contactId
    );
    profile.value = data;
  } catch (e) {
    error.value = e.response?.data?.error || 'Unable to load app profile';
  } finally {
    loading.value = false;
  }
};

const openTransactions = (title, transactions) => {
  transactionTitle.value = title;
  selectedTransactions.value = [...transactions].sort(
    (a, b) =>
      (b.timestamp_millis || b.purchaseDateMillis || 0) -
      (a.timestamp_millis || a.purchaseDateMillis || 0)
  );
  showTransactions.value = true;
};

const transactionDate = transaction => {
  const value =
    transaction.timestamp ||
    transaction.purchaseDate ||
    transaction.timestamp_millis ||
    transaction.purchaseDateMillis;
  return value
    ? new Intl.DateTimeFormat(undefined, {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(new Date(value))
    : '—';
};

const transactionLabel = transaction =>
  transaction.reason ||
  transaction.pack_marketing_title ||
  transaction.productId ||
  transaction.productIdentifier ||
  transaction.product_id ||
  transaction.description ||
  '—';
const transactionPlatform = transaction =>
  transaction.platform ? transaction.platform.toUpperCase() : '—';

onMounted(checkProfile);
</script>

<template>
  <div class="px-4 py-3 text-sm text-n-slate-12">
    <p v-if="!email" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.NO_EMAIL') }}
    </p>
    <p v-else-if="loading" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.LOADING') }}
    </p>
    <p v-else-if="error" class="text-n-ruby-11">{{ error }}</p>
    <p v-else-if="profile && !profile.auth?.found" class="text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.NOT_FOUND') }}
    </p>

    <div v-else-if="profile" class="space-y-4">
      <div class="rounded-lg bg-n-alpha-2 p-3">
        <p class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.FIREBASE_ID') }}
        </p>
        <p class="mt-1 break-all font-mono text-xs">{{ profile.auth.uid }}</p>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div class="rounded-lg bg-n-alpha-2 p-3">
          <p class="text-xs text-n-slate-11">
            {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.AVAILABLE_CREDITS') }}
          </p>
          <p class="mt-1 text-xl font-semibold">
            {{ credits.available_credits ?? '—' }}
          </p>
        </div>
        <div class="rounded-lg bg-n-alpha-2 p-3">
          <p class="text-xs text-n-slate-11">
            {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.USED_CREDITS') }}
          </p>
          <p class="mt-1 text-xl font-semibold">
            {{ credits.used_credits ?? '—' }}
          </p>
        </div>
      </div>

      <button
        v-if="creditTransactions.length"
        class="w-full rounded-lg border border-n-weak px-3 py-2 text-left hover:bg-n-alpha-2"
        @click="
          openTransactions(
            $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.CREDIT_TRANSACTIONS'),
            creditTransactions
          )
        "
      >
        <span class="font-medium">{{
          $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.CREDIT_TRANSACTIONS')
        }}</span>
        <span class="float-right text-n-slate-11">{{
          creditTransactions.length
        }}</span>
      </button>

      <div class="rounded-lg bg-n-alpha-2 p-3">
        <div class="flex items-center justify-between gap-2">
          <p class="text-xs text-n-slate-11">
            {{
              $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.CURRENT_SUBSCRIPTION')
            }}
          </p>
          <span
            class="rounded-full bg-n-alpha-3 px-2 py-0.5 text-xs font-medium"
            >{{ subscription.status || '—' }}</span
          >
        </div>
        <p class="mt-2 font-medium">{{ subscription.product_id || '—' }}</p>
        <p v-if="subscription.permissions" class="mt-1 text-xs text-n-slate-11">
          {{ subscription.permissions.photos_used_in_current_period ?? 0 }} /
          {{ subscription.permissions.photos_limit_per_period ?? '—' }}
          {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.PHOTOS_THIS_PERIOD') }}
        </p>
      </div>

      <button
        v-if="subscriptionTransactions.length"
        class="w-full rounded-lg border border-n-weak px-3 py-2 text-left hover:bg-n-alpha-2"
        @click="
          openTransactions(
            $t(
              'CONVERSATION_SIDEBAR.FIREBASE_PROFILE.SUBSCRIPTION_TRANSACTIONS'
            ),
            subscriptionTransactions
          )
        "
      >
        <span class="font-medium">{{
          $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.SUBSCRIPTION_TRANSACTIONS')
        }}</span>
        <span class="float-right text-n-slate-11">{{
          subscriptionTransactions.length
        }}</span>
      </button>
    </div>

    <woot-modal
      v-model:show="showTransactions"
      :on-close="() => (showTransactions = false)"
      size="modal-big"
    >
      <woot-modal-header :header-title="transactionTitle" />
      <div class="max-h-[65vh] overflow-y-auto px-6 pb-6">
        <div
          v-for="transaction in selectedTransactions"
          :key="
            transaction.transaction_id ||
            transaction.transactionIdentifier ||
            transaction.timestamp_millis ||
            transaction.purchaseDateMillis
          "
          class="border-b border-n-weak py-3 last:border-0"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="font-medium">{{ transactionLabel(transaction) }}</p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ transactionDate(transaction) }}
              </p>
            </div>
            <span
              class="rounded bg-n-alpha-3 px-2 py-0.5 text-xs font-medium"
              >{{ transactionPlatform(transaction) }}</span
            >
          </div>
          <p class="mt-2 text-xs text-n-slate-11">
            <span v-if="transaction.credits !== undefined"
              >{{ transaction.credits }}
              {{ $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.CREDITS') }}</span
            ><span v-if="transaction.price"> · {{ transaction.price }}</span
            ><span v-if="transaction.country"> · {{ transaction.country }}</span
            ><span v-if="transaction.app_version">
              {{
                $t('CONVERSATION_SIDEBAR.FIREBASE_PROFILE.APP_VERSION', {
                  version: transaction.app_version,
                })
              }}</span
            >
          </p>
        </div>
      </div>
    </woot-modal>
  </div>
</template>
