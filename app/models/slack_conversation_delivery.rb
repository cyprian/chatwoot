class SlackConversationDelivery < ApplicationRecord
  belongs_to :slack_inbox_configuration
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :slack_inbox_configuration_id }
  validates :channel_id, :thread_ts, presence: true
end
