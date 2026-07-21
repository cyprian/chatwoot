class SlackNotificationListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return if message.external_source_id_slack.present?

    event_name = message_event_name(message)
    return if event_name.blank?

    enqueue(message.inbox, event_name, message)
  end

  def assignee_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    enqueue(conversation.inbox, 'assignment_changed', conversation)
  end

  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    enqueue(conversation.inbox, 'status_changed', conversation)
  end

  private

  def message_event_name(message)
    return 'private_note' if message.private?
    return 'outgoing_message' if message.outgoing?
    return unless message.incoming?

    first_incoming_message?(message) ? 'conversation_created' : 'incoming_message'
  end

  def first_incoming_message?(message)
    !message.conversation.messages.incoming.where.not(id: message.id).exists?
  end

  def enqueue(inbox, event_name, resource)
    configuration = inbox.slack_inbox_configuration
    return unless configuration&.event_enabled?(event_name)
    return unless configuration.matches?(resource.is_a?(Message) ? resource.conversation : resource)

    SlackInboxNotificationJob.perform_later(configuration, event_name, resource)
  end
end
