class SlackNotifications::DeliveryService
  pattr_initialize [:configuration!, :event_name!, :resource!]

  def perform
    response = configuration.slack_workspace_connection.slack_client.chat_postMessage(**message_payload)
    store_thread(response['ts']) if delivery.blank? && thread_updates?
    configuration.update!(last_delivered_at: Time.current, last_error: nil)
  rescue StandardError => e
    configuration.update!(last_error: e.message)
    raise
  end

  private

  def message_payload
    {
      channel: configuration.channel_id,
      text: fallback_text,
      blocks: blocks,
      thread_ts: thread_ts,
      unfurl_links: false,
      unfurl_media: false
    }.compact
  end

  def blocks
    result = [header_block]
    fields = detail_fields
    result << { type: 'section', fields: fields } if fields.any?
    result << body_block if body_text.present?
    result << attachments_block if attachment_names.any?
    result << actions_block if include_content?('conversation_link')
    result
  end

  def header_block
    {
      type: 'section',
      text: { type: 'mrkdwn', text: "#{event_emoji} *#{escape(event_title)}*" }
    }
  end

  def detail_fields
    [
      optional_field('subject', 'Subject', subject),
      optional_field('sender_name', 'From', sender_name),
      optional_field('sender_email', 'Email', sender_email),
      optional_field('inbox_name', 'Inbox', conversation.inbox.name),
      optional_field('priority', 'Priority', conversation.priority&.titleize),
      optional_field('assignee', 'Assignee', conversation.assignee&.name),
      optional_field('labels', 'Labels', conversation.label_list.join(', '))
    ].compact
  end

  def optional_field(content_key, label, value)
    field(label, value) if include_content?(content_key) && value.present?
  end

  def field(label, value)
    { type: 'mrkdwn', text: "*#{label}:*\n#{escape(value)}" }
  end

  def body_block
    quoted = escape(body_text).gsub("\n", "\n> ")
    { type: 'section', text: { type: 'mrkdwn', text: "> #{quoted}" } }
  end

  def attachments_block
    names = attachment_names.map { |name| escape(name) }.join(', ')
    { type: 'context', elements: [{ type: 'mrkdwn', text: ":paperclip: *Attachments:* #{names}" }] }
  end

  def actions_block
    {
      type: 'actions',
      elements: [
        {
          type: 'button',
          text: { type: 'plain_text', text: 'Open in Support' },
          url: conversation_url,
          action_id: 'open_chatwoot_conversation'
        }
      ]
    }
  end

  def event_title
    {
      'conversation_created' => 'New conversation',
      'incoming_message' => 'New customer message',
      'outgoing_message' => 'Agent reply',
      'private_note' => 'Private note',
      'assignment_changed' => 'Assignment changed',
      'status_changed' => "Conversation #{conversation.status}"
    }.fetch(event_name)
  end

  def event_emoji
    {
      'conversation_created' => ':inbox_tray:',
      'incoming_message' => ':speech_balloon:',
      'outgoing_message' => ':left_speech_bubble:',
      'private_note' => ':lock:',
      'assignment_changed' => ':busts_in_silhouette:',
      'status_changed' => ':large_green_circle:'
    }.fetch(event_name)
  end

  def fallback_text
    [event_title, subject, sender_email, body_text].compact.join(' — ').truncate(500)
  end

  def subject
    return unless message

    message.content_attributes.dig('email', 'subject') || message.content_attributes.dig(:email, :subject)
  end

  def sender_name
    message&.sender&.try(:name) || conversation.contact&.name
  end

  def sender_email
    message&.sender&.try(:email) || conversation.contact&.email
  end

  def body_text
    return unless message

    mode = configuration.rules.dig('content', 'body')
    return if mode == 'none'

    raw_content = message.processed_message_content || message.content
    return if raw_content.blank?

    content = ActionView::Base.full_sanitizer.sanitize(raw_content).squish
    limit = mode == 'full' ? 2500 : configuration.rules.dig('content', 'body_preview_length').to_i.clamp(100, 2500)
    content.truncate(limit)
  end

  def attachment_names
    return [] unless message && include_content?('attachments')

    message.attachments.filter_map do |attachment|
      attachment.file.filename.to_s if attachment.file.attached?
    end
  end

  def include_content?(key)
    configuration.rules.dig('content', key) == true
  end

  def thread_updates?
    configuration.rules['thread_updates'] == true
  end

  def delivery
    @delivery ||= configuration.slack_conversation_deliveries.find_by(conversation: conversation)
  end

  def thread_ts
    delivery&.thread_ts if thread_updates?
  end

  def store_thread(timestamp)
    configuration.slack_conversation_deliveries.create!(
      conversation: conversation,
      channel_id: configuration.channel_id,
      thread_ts: timestamp
    )
  end

  def message
    resource if resource.is_a?(Message)
  end

  def conversation
    @conversation ||= message ? message.conversation : resource
  end

  def conversation_url
    "#{ENV.fetch('FRONTEND_URL')}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}"
  end

  def escape(value)
    value.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end
