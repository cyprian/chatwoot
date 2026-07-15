#!/usr/bin/env ruby
# frozen_string_literal: true

def replace_once(path, expected, replacement)
  content = File.read(path)
  return if content.include?(replacement)

  raise "Expected source not found in #{path}" unless content.include?(expected)

  File.write(path, content.sub(expected, replacement))
end

app_root = ENV.fetch('APP_ROOT', '/app')
hub = "#{app_root}/lib/chatwoot_hub.rb"
replace_once(
  hub,
  "  DEFAULT_BASE_URL = 'https://hub.2.chatwoot.com'.freeze\n",
  "  DEFAULT_BASE_URL = 'https://hub.2.chatwoot.com'.freeze\n\n" \
    "  # Hub requests transmit installation metadata and, depending on the endpoint,\n" \
    "  # registration details, telemetry, or push payloads. Keep this opt-in for\n" \
    "  # self-hosted Eyepic deployments.\n" \
    "  def self.outbound_enabled?\n" \
    "    ActiveModel::Type::Boolean.new.cast(ENV.fetch('CHATWOOT_HUB_ENABLED', false))\n" \
    "  end\n"
)

{
  "  def self.sync_with_hub\n" => "  def self.sync_with_hub\n    return unless outbound_enabled?\n\n",
  "  def self.register_instance(company_name, owner_name, owner_email)\n" =>
    "  def self.register_instance(company_name, owner_name, owner_email)\n    return unless outbound_enabled?\n\n",
  "  def self.send_push(fcm_options)\n" => "  def self.send_push(fcm_options)\n    return unless outbound_enabled?\n\n",
  "  def self.send_push_with_response(fcm_options)\n" => "  def self.send_push_with_response(fcm_options)\n    return unless outbound_enabled?\n\n",
  "  def self.emit_event(event_name, event_data)\n" =>
    "  def self.emit_event(event_name, event_data)\n    return unless outbound_enabled?\n"
}.each { |expected, replacement| replace_once(hub, expected, replacement) }

replace_once(
  "#{app_root}/app/jobs/internal/check_new_versions_job.rb",
  "    return unless Rails.env.production?\n",
  "    return unless Rails.env.production?\n    return unless ChatwootHub.outbound_enabled?\n"
)
replace_once(
  "#{app_root}/app/jobs/internal/trigger_daily_scheduled_items_job.rb",
  "    return unless Rails.env.production?\n\n    Internal::CheckNewVersionsJob.set",
  "    return unless Rails.env.production?\n    return unless ChatwootHub.outbound_enabled?\n\n    Internal::CheckNewVersionsJob.set"
)
