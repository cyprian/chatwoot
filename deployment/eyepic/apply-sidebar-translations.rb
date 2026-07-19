require 'json'

path = '/app/app/javascript/dashboard/i18n/locale/en/conversation.json'
locale = JSON.parse(File.read(path))
sidebar = locale.fetch('CONVERSATION_SIDEBAR')

sidebar.fetch('ACCORDION').merge!(
  'FIREBASE_PROFILE' => 'App profile',
  'EYE_PHOTO' => 'Eye.photo data'
)

sidebar['FIREBASE_PROFILE'] = {
  'CHECK' => 'Check app profile',
  'LOADING' => 'Loading app profile…',
  'NO_EMAIL' => 'This contact has no email address.',
  'NOT_FOUND' => 'No Firebase user was found for this email.',
  'FIREBASE_ID' => 'Firebase ID',
  'CREDITS' => 'Credits',
  'AVAILABLE_CREDITS' => 'Available credits',
  'USED_CREDITS' => 'Used credits',
  'CREDIT_TRANSACTIONS' => 'Credit transactions',
  'CURRENT_SUBSCRIPTION' => 'Current subscription',
  'SUBSCRIPTION_TRANSACTIONS' => 'Subscription transactions',
  'PHOTOS_THIS_PERIOD' => 'photos this period',
  'ERROR' => 'Unable to load app profile'
}

sidebar['EYE_PHOTO'] = {
  'LOADING' => 'Loading Eye.photo data…',
  'REFRESH' => 'Refresh',
  'NO_EMAIL' => 'This contact has no email address.',
  'NOT_FOUND' => 'No Eye.photo studio is associated with this email.',
  'STUDIO' => 'Studio',
  'STATUS' => 'Status',
  'PLAN' => 'Plan',
  'PHOTOS' => 'Photos',
  'USERS' => 'users',
  'USER' => 'user',
  'SHOW_USERS' => 'Show users',
  'EMAIL_USER' => 'Email {name}',
  'START_CONVERSATION' => 'Start a new conversation with {name}',
  'VIEW_IN_EYE_PHOTO' => 'View in Eye.photo',
  'ERROR' => 'Unable to load Eye.photo data.'
}

locale.fetch('CONVERSATION')['TRANSLATE_TO_ENGLISH'] = 'Translate to English'

File.write(path, "#{JSON.pretty_generate(locale)}\n")
