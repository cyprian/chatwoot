class CreateCustomSlackNotifications < ActiveRecord::Migration[7.1]
  def up
    create_workspace_connections
    create_inbox_configurations
    create_conversation_deliveries
  end

  def down
    drop_table :slack_conversation_deliveries
    drop_table :slack_inbox_configurations
    drop_table :slack_workspace_connections
  end

  private

  def create_workspace_connections
    create_table :slack_workspace_connections do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.string :access_token
      t.string :slack_team_id
      t.string :slack_team_name
      t.string :slack_bot_user_id
      t.integer :status, null: false, default: 0
      t.text :last_error
      t.timestamps
    end

    add_workspace_connection_indexes
  end

  def add_workspace_connection_indexes
    add_index :slack_workspace_connections, :account_id
    add_index :slack_workspace_connections,
              [:account_id, :client_id, :slack_team_id],
              unique: true,
              where: 'slack_team_id IS NOT NULL',
              name: 'idx_slack_connections_on_account_app_and_team'
    add_foreign_key :slack_workspace_connections, :accounts
  end

  def create_inbox_configurations
    create_table :slack_inbox_configurations do |t|
      t.integer :account_id, null: false
      t.integer :inbox_id, null: false
      t.references :slack_workspace_connection,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_slack_inbox_configs_on_connection' }
      t.boolean :enabled, null: false, default: false
      t.string :channel_id, null: false
      t.string :channel_name, null: false
      t.jsonb :rules, null: false, default: {}
      t.datetime :last_delivered_at
      t.text :last_error
      t.timestamps
    end

    add_index :slack_inbox_configurations, :account_id
    add_index :slack_inbox_configurations, :inbox_id, unique: true
    add_foreign_key :slack_inbox_configurations, :accounts
    add_foreign_key :slack_inbox_configurations, :inboxes
  end

  def create_conversation_deliveries
    create_table :slack_conversation_deliveries do |t|
      t.references :slack_inbox_configuration,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_slack_deliveries_on_configuration' }
      t.integer :conversation_id, null: false
      t.string :channel_id, null: false
      t.string :thread_ts, null: false
      t.timestamps
    end

    add_index :slack_conversation_deliveries, :conversation_id
    add_foreign_key :slack_conversation_deliveries, :conversations
    add_index :slack_conversation_deliveries,
              [:slack_inbox_configuration_id, :conversation_id],
              unique: true,
              name: 'idx_slack_deliveries_on_config_and_conversation'
  end
end
