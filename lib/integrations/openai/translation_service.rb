class Integrations::Openai::TranslationService
  class Error < StandardError
  end

  pattr_initialize [:message!]

  def perform
    Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
      context.chat(model: model)
             .with_instructions(system_prompt)
             .ask(message.content)
             .content
             .strip
    end
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error "OpenAI message translation failed: #{e.message}"
    raise Error, 'Unable to translate this message right now.'
  end

  private

  def api_key
    openai_hook.settings['api_key'].presence ||
      raise(Error, 'OpenAI translation is not configured.')
  end

  def openai_hook
    @openai_hook ||= message.account.hooks.enabled.find_by!(app_id: 'openai')
  rescue ActiveRecord::RecordNotFound
    raise Error, 'OpenAI translation is not configured.'
  end

  def api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    "#{endpoint.chomp('/')}/v1"
  end

  def model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || Llm::Config::DEFAULT_MODEL
  end

  def system_prompt
    <<~PROMPT
      You are a professional support-message translator.
      Translate the user's message into English.
      Preserve the original meaning, tone, names, URLs, line breaks, and markdown formatting.
      Return only the English translation with no explanation or prefacing text.
    PROMPT
  end
end
