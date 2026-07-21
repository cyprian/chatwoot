class SlackInboxConfiguration < ApplicationRecord
  DEFAULT_RULES = {
    'events' => {
      'conversation_created' => true,
      'incoming_message' => true,
      'outgoing_message' => false,
      'private_note' => false,
      'assignment_changed' => false,
      'status_changed' => false
    },
    'conditions' => {
      'minimum_priority' => nil,
      'include_labels' => [],
      'exclude_labels' => []
    },
    'content' => {
      'sender_name' => true,
      'sender_email' => true,
      'subject' => true,
      'body' => 'preview',
      'body_preview_length' => 1000,
      'attachments' => true,
      'assignee' => true,
      'labels' => true,
      'priority' => true,
      'inbox_name' => true,
      'conversation_link' => true
    },
    'thread_updates' => true
  }.freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :slack_workspace_connection
  has_many :slack_conversation_deliveries, dependent: :destroy

  validates :channel_id, :channel_name, presence: true
  validates :inbox_id, uniqueness: true
  validate :matching_account
  validate :valid_rules

  before_validation :apply_rule_defaults
  after_update_commit :clear_conversation_deliveries, if: :delivery_target_changed?

  def event_enabled?(event_name)
    enabled? && rules.dig('events', event_name) == true
  end

  def matches?(conversation)
    return false unless priority_matches?(conversation)

    labels = conversation.label_list
    included = Array(rules.dig('conditions', 'include_labels'))
    excluded = Array(rules.dig('conditions', 'exclude_labels'))
    (included.empty? || labels.intersect?(included)) && !labels.intersect?(excluded)
  end

  private

  def apply_rule_defaults
    self.rules = DEFAULT_RULES.deep_merge((rules || {}).deep_stringify_keys)
  end

  def matching_account
    return if inbox.blank? || slack_workspace_connection.blank?
    return if inbox.account_id == account_id && slack_workspace_connection.account_id == account_id

    errors.add(:account, 'must match the inbox and Slack workspace connection')
  end

  def valid_rules
    return if rules.blank?

    body_mode = rules.dig('content', 'body')
    minimum_priority = rules.dig('conditions', 'minimum_priority')
    preview_length = rules.dig('content', 'body_preview_length').to_i
    valid_priority = minimum_priority.blank? || Conversation.priorities.key?(minimum_priority)

    errors.add(:rules, 'contains an invalid body mode') unless %w[none preview full].include?(body_mode)
    errors.add(:rules, 'contains an invalid minimum priority') unless valid_priority
    return if preview_length.between?(100, 2500)

    errors.add(:rules, 'contains an invalid preview length')
  end

  def priority_matches?(conversation)
    minimum = rules.dig('conditions', 'minimum_priority')
    return true if minimum.blank?
    return false if conversation.priority.blank?

    Conversation.priorities.fetch(conversation.priority) >= Conversation.priorities.fetch(minimum)
  end

  def delivery_target_changed?
    saved_change_to_slack_workspace_connection_id? || saved_change_to_channel_id?
  end

  def clear_conversation_deliveries
    slack_conversation_deliveries.destroy_all
  end
end
