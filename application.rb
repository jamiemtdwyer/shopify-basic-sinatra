require 'sinatra'
require 'httparty'
require 'dotenv/load'

API_KEY = ENV['API_KEY']
SECRET_KEY = ENV['SECRET_KEY']
REDIRECT_URI = 'https://364d8b06.ngrok.io/auth/shopify/callback'
SCOPE = 'read_products'

get '/' do
  shop = params[:shop]

  return [403, "Invalid shop parameter (not a myshopify subdomain)"] unless valid_shop?(shop)

  # build permission url
  permission_url = "https://#{shop}/admin/oauth/authorize?client_id=#{API_KEY}"\
    "&scope=#{SCOPE}&redirect_uri=#{REDIRECT_URI}"

  redirect permission_url
end

get '/auth/shopify/callback' do
  shop = params[:shop]

  # return early if signature doesn't match
  return [403, "This request is not from Shopify!"] unless valid_signature?

  response = HTTParty.post(
    "https://#{shop}/admin/oauth/access_token",
    body: {
      client_id: API_KEY,
      client_secret: SECRET_KEY,
      code: params[:code]
    }
  )

  # return early if obtaining access token was not successful
  return [500, "There was an error obtaining the access token"] unless response.code == 200
  access_token = response['access_token']

  # perform an authenticated request to the Shopify API
  response = HTTParty.get(
    "https://#{shop}/admin/products.json",
    :query => { 'limit': 10 },
    :headers => { 'X-SHOPIFY-ACCESS-TOKEN': access_token },
    :format => :json
  )

  @products = response['products']

  # render the view
  erb :products
end

helpers do
  def valid_shop?(shop)
    !!(/[a-zA-Z0-9][a-zA-Z0-9\-]*\.#{Regexp.escape('myshopify.com')}[\/]?\z/ =~ shop)
  end

  def valid_signature?
    params = request.GET

    signature = params['hmac']
    timestamp = params['timestamp']
    return false unless signature && timestamp

    return false unless timestamp.to_i > Time.now.to_i - 600

    calculated_signature = hmac_sign(params, SECRET_KEY)
    Rack::Utils.secure_compare(signature, calculated_signature)
  end

  def hmac_sign(params, secret)
    params = params.dup
    params.delete('hmac')

    # join keys lexicographically
    query = params.map{ |k,v| "#{URI.escape(k.to_s, '&=%')}=#{URI.escape(v.to_s, '&%')}" }.sort.join('&')

    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret, query)
  end
end