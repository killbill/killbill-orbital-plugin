class AddTraceNumber < ActiveRecord::Migration

  def change
    add_column :orbital_responses, :params_trace_number, :string
  end
end
