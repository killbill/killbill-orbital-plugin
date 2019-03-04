class AddKbTransactionPaymentIdIndexToOrbitalResponses < ActiveRecord::Migration

  def change
    add_index(:orbital_responses, [:kb_payment_transaction_id, :kb_tenant_id], :name => 'index_orbital_responses_kb_payment_txn_id_kb_tenant_id')
  end
end
