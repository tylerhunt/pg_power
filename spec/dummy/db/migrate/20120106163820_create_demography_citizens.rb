class CreateDemographyCitizens < ActiveRecord::Migration
  def change
    create_table 'demography.citizens' do |t|
      t.integer :country_id
      t.integer :user_id
      t.string :first_name 
      t.string :last_name

      t.timestamps
    end

    add_index('demography.citizens', :country_id)
    add_index('demography.citizens', :user_id)

    set_table_comment 'demography.citizens', "Citizens Info"

    set_column_comment 'demography.citizens', :country_id, 'Country key'

    set_column_comments 'demography.citizens',
      :first_name => "First name",
      :last_name  => "Last name"
  end
end
