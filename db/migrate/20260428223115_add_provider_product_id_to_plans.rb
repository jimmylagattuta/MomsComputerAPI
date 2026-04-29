class AddProviderProductIdToPlans < ActiveRecord::Migration[7.2]
  def change
    add_column :plans, :provider_product_id, :string
    add_index :plans, :provider_product_id, unique: true
  end
end