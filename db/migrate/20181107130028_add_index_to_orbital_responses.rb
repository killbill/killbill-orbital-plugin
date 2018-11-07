class AddIndexToOrbitalResponses < ActiveRecord::Migration

  def change
    add_index :orbital_responses, :success
  end
end
