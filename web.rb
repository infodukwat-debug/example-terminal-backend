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
    intent = Stripe::PaymentIntent.create({
      amount: params[:amount],
      currency: params[:currency],
      payment_method_types: ['card_present'],
      capture_method: 'manual',
    })
    { client_secret: intent.client_secret }.to_json
  rescue Stripe::StripeError => e
    status 400
    log_info("Error creating PaymentIntent: #{e.message}")
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
    # Lecture du corps JSON
    request_body = JSON.parse(request.body.read)
    intent_id = request_body['payment_intent_id']

    if intent_id.nil? || intent_id.empty?
      status 400
      content_type :json
      return { error: "Missing payment_intent_id" }.to_json
    end

    # Capture du PaymentIntent
    intent = Stripe::PaymentIntent.capture(intent_id)
    content_type :json
    status 200
    return intent.to_json

  rescue Stripe::StripeError => e
    status 400
    content_type :json
    return { error: "Stripe error: #{e.message}" }.to_json
  rescue JSON::ParserError => e
    status 400
    content_type :json
    return { error: "Invalid JSON: #{e.message}" }.to_json
  rescue StandardError => e
    status 500
    content_type :json
    return { error: "Internal error: #{e.message}" }.to_json
  end
end

# Autres routes (list_locations, create_location, etc.) – conservez-les si vous en avez besoin.
