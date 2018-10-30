class AddIndexToOrbitalResponses < ActiveRecord::Migration

  def change
    add_index :orbital_responses, [:params_tx_ref_num, :kb_tenant_id]
  end
end
