class AddPointsToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :after_army_trip, :string
    add_column :users, :top_scorer, :string
    add_column :users, :points, :integer
  end
end
