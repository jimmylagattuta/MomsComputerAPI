# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Plan.find_or_create_by!(provider_product_id: "moms_computer_monthly") do |plan|
#   plan.name = "Mom's Computer Monthly"
#   plan.price_cents = 999
#   plan.billing_period = "monthly"
#   plan.trial_days = 0
#   plan.active = true
#   plan.features = {
#     support_calls_per_month: 3,
#     support_text: true,
#     premium_access: true
#   }
# end