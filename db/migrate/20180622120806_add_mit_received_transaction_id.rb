class AddTraceNumber < ActiveRecord::Migration

  def change
    add_column :orbital_responses, :params_mit_received_transaction_id, :string
  end
end
