# Importing Stripe Customers and Subscriptions
# to Chargify as Customers with a Subscription and Components

require "stripe"
require 'chargify_api_ares'

Stripe.api_key = ENV['STRIPE_SECRET_KEY']

Chargify.configure do |c|
  c.subdomain = ENV['CHARGIFY_SUBDOMAIN']
  c.api_key   = ENV['CHARGIFY_API_KEY']
end

#TODO: pagination over Stripe Customers
customers = Stripe::Customer.all(:limit => 1)

customers.each { |cust|
  puts cust

  #TODO: decide how to split 'description' into first/last name

  newcust = Chargify::Customer.create(
    :first_name   => cust.description,
    :last_name    => cust.description,
    :email        => cust.email
  )
  puts newcust.inspect
  customer_id = newcust.id

  # single subscription, using cust.id as the vault token for the payment profile

  card = cust.sources.data[0]
  sub1 = cust.subscriptions.data[0]

  #TODO: Multiple Stripe Subscriptions for a customer can have different period end dates. Which one should be used for the single Chargify Subscription?

  newsub = Chargify::Subscription.create(
    :customer_id => customer_id,
    :product_handle => 'basic',
    :next_billing_at => Time.at(sub1.current_period_end).to_datetime,
    :credit_card_attributes => {
      :vault_token => cust.id,
      :current_vault => 'stripe',
      :expiration_month => card.exp_month,
      :expiration_year => card.exp_year,
      :last_four => card.last4,
      :card_type => card.brand.downcase,
      :first_name => cust.description,
      :last_name => cust.description
    }
    #TODO: Can you include components when creating a subscription?
    #,
    #:components => [
    #  {"142511" => 5},
    #  {"82831" => 3}
    #]
  )
  puts newsub.inspect

  # Mapping Stripe Subscriptions to Chargify Components
  mapping = {"monthly33.00" => "142511", "monthly25.00" => "82831"}

  cust.subscriptions.data.each { |stripesub|

    Chargify::Allocation.create(
      :subscription_id => newsub.id,
      :component_id => mapping[stripesub.plan.id],
      :quantity => stripesub.quantity,
      :proration_upgrade_scheme => "no-prorate",
      :proration_downgrade_scheme => "no-prorate",
    )
  }

}

# References
# http://stackoverflow.com/questions/7816365/how-to-convert-a-unix-timestamp-seconds-since-epoch-to-ruby-datetime
# https://github.com/chargify/chargify_api_ares/blob/fb5829412a7f8d15464b1d5a296cf496006e49c5/spec/remote/remote_spec.rb
# https://docs.chargify.com/api-subscriptions
