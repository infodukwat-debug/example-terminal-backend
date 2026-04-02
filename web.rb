require 'sinatra'
require 'stripe'
require 'dotenv'
require 'json'
require 'sinatra/cross_origin'

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end

options "*" do
  response.headers["Allow"] = "GET, POST, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
  response.headers["Access-Control-Allow-Origin"] = "*"
  200
end

Dotenv.load
Stripe.api_key = ENV['STRIPE_ENV'] == 'production' ? ENV['STRIPE_SECRET_KEY'] : ENV['STRIPE_TEST_SECRET_KEY']
Stripe.api_version = '2020-03-02'

def log_info(message)
  puts "\n" + message + "\n\n"
  return message
end

get '/' do
  status 200
  send_file 'index.html'
end

def validateApiKey
  if Stripe.api_key.nil? || Stripe.api_key.empty?
    return "Error: you provided an empty secret key. Please provide your test mode secret key. For more information, see https://stripe.com/docs/keys"
  end
  if Stripe.api_key.start_with?('pk')
    return "Error: you used a publishable key to set up the example backend. Please use your test mode secret key. For more information, see https://stripe.com/docs/keys"
  end
  if Stripe.api_key.start_with?('sk_live')
    return "Error: you used a live mode secret key to set up the example backend. Please use your test mode secret key. For more information, see https://stripe.com/docs/keys#test-live-modes"
  end
  return nil
end

post '/register_reader' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    reader = Stripe::Terminal::Reader.create(
      :registration_code => params[:registration_code],
      :label => params[:label],
      :location => params[:location]
    )
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error registering reader! #{e.message}")
  end

  log_info("Reader registered: #{reader.id}")
  status 200
  return reader.to_json
end

post '/connection_token' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    token = Stripe::Terminal::ConnectionToken.create
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error creating ConnectionToken! #{e.message}")
  end

  content_type :json
  status 200
  return {:secret => token.secret}.to_json
end

post '/create_payment_intent' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    # Lire le JSON s'il est présent, sinon utiliser les paramètres classiques
    request_body = JSON.parse(request.body.read) rescue {}
    amount = request_body['amount'] || params[:amount]
    currency = request_body['currency'] || params[:currency]

    if amount.nil? || currency.nil?
      status 400
      content_type :json
      return { error: "Missing amount or currency" }.to_json
    end

    intent = Stripe::PaymentIntent.create({
      amount: amount.to_i,
      currency: currency,
      payment_method_types: ['card_present'],
      capture_method: 'manual',
    })
    content_type :json
    { client_secret: intent.client_secret }.to_json
  rescue Stripe::StripeError => e
    status 400
    content_type :json
    { error: "Stripe error: #{e.message}" }.to_json
  rescue => e
    status 500
    content_type :json
    { error: "Internal error: #{e.message}" }.to_json
  end
end

# NOUVELLE ROUTE : mise à jour du montant avant capture
post '/update_payment_intent_amount' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    content_type :json
    return { error: validationError }.to_json
  end

  begin
    request_body = JSON.parse(request.body.read)
    intent_id = request_body['payment_intent_id']
    new_amount = request_body['new_amount']

    if intent_id.nil? || new_amount.nil?
      status 400
      content_type :json
      return { error: "Missing payment_intent_id or new_amount" }.to_json
    end

    intent = Stripe::PaymentIntent.update(intent_id, { amount: new_amount.to_i })
    content_type :json
    intent.to_json
  rescue Stripe::StripeError => e
    status 400
    content_type :json
    { error: "Stripe error: #{e.message}" }.to_json
  rescue JSON::ParserError => e
    status 400
    content_type :json
    { error: "Invalid JSON: #{e.message}" }.to_json
  rescue => e
    status 500
    content_type :json
    { error: "Internal error: #{e.message}" }.to_json
  end
end

post '/capture_payment_intent' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    content_type :json
    return { error: validationError }.to_json
  end

  begin
    request_body = JSON.parse(request.body.read)
    intent_id = request_body['payment_intent_id']
    if intent_id.nil?
      status 400
      content_type :json
      return { error: "Missing payment_intent_id" }.to_json
    end

    intent = Stripe::PaymentIntent.capture(intent_id)
    content_type :json
    intent.to_json
  rescue Stripe::StripeError => e
    status 400
    content_type :json
    { error: "Stripe error: #{e.message}" }.to_json
  rescue JSON::ParserError => e
    status 400
    content_type :json
    { error: "Invalid JSON: #{e.message}" }.to_json
  rescue => e
    status 500
    content_type :json
    { error: "Internal error: #{e.message}" }.to_json
  end
end

get '/list_locations' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    locations = Stripe::Terminal::Location.list(limit: 100)
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error fetching Locations! #{e.message}")
  end

  log_info("#{locations.data.size} Locations successfully fetched")
  status 200
  content_type :json
  return locations.data.to_json
end

post '/create_location' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    location = Stripe::Terminal::Location.create(
      display_name: params[:display_name],
      address: params[:address]
    )
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error creating Location! #{e.message}")
  end

  log_info("Location successfully created: #{location.id}")
  status 200
  content_type :json
  return location.to_json
end

post '/create_setup_intent' do
  validationError = validateApiKey
  if !validationError.nil?
    status 400
    return log_info(validationError)
  end

  begin
    setup_intent_params = {
      :payment_method_types => params[:payment_method_types] || ['card_present'],
    }
    if !params[:customer].nil?
      setup_intent_params[:customer] = params[:customer]
    end
    if !params[:description].nil?
      setup_intent_params[:description] = params[:description]
    end
    if !params[:on_behalf_of].nil?
      setup_intent_params[:on_behalf_of] = params[:on_behalf_of]
    end

    setup_intent = Stripe::SetupIntent.create(setup_intent_params)
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error creating SetupIntent! #{e.message}")
  end

  log_info("SetupIntent successfully created: #{setup_intent.id}")
  status 200
  return {:intent => setup_intent.id, :secret => setup_intent.client_secret}.to_json
end

post '/attach_payment_method_to_customer' do
  begin
    customer = lookupOrCreateExampleCustomer
    payment_method = Stripe::PaymentMethod.attach(
      params[:payment_method_id],
      {
        customer: customer.id,
        expand: ["customer"],
    })
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error attaching PaymentMethod to Customer! #{e.message}")
  end

  log_info("Attached PaymentMethod to Customer: #{customer.id}")
  status 200
  return payment_method.to_json
end

def lookupOrCreateExampleCustomer
  customerEmail = "example@test.com"
  begin
    customerList = Stripe::Customer.list(email: customerEmail, limit: 1).data
    if (customerList.length == 1)
      return customerList[0]
    else
      return Stripe::Customer.create(email: customerEmail)
    end
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error creating or retreiving customer! #{e.message}")
  end
end

post '/update_payment_intent' do
  payment_intent_id = params["payment_intent_id"]
  if payment_intent_id.nil?
    status 400
    return log_info("'payment_intent_id' is a required parameter")
  end

  begin
    allowed_keys = ["receipt_email"]
    update_params = params.select { |k, _| allowed_keys.include?(k) }
    payment_intent = Stripe::PaymentIntent.update(
      payment_intent_id,
      update_params
    )
    log_info("Updated PaymentIntent #{payment_intent_id}")
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error updating PaymentIntent #{payment_intent_id}. #{e.message}")
  end

  status 200
  return {:intent => payment_intent.id, :secret => payment_intent.client_secret}.to_json
end

post '/cancel_payment_intent' do
  begin
    id = params["payment_intent_id"]
    payment_intent = Stripe::PaymentIntent.cancel(id)
  rescue Stripe::StripeError => e
    status 402
    return log_info("Error canceling PaymentIntent! #{e.message}")
  end

  log_info("PaymentIntent successfully canceled: #{id}")
  status 200
  return {:intent => payment_intent.id, :secret => payment_intent.client_secret}.to_json
end
