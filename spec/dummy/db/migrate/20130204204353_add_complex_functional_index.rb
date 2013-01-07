class AddComplexFunctionalIndex < ActiveRecord::Migration
  def change
    add_index :pets, ["to_tsvector('english'::regconfig, name)", "color"]
  end
end
