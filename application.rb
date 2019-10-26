require 'sinatra'
require 'httparty'
require 'dotenv/load'

API_KEY = ENV['API_KEY']
SECRET_KEY = ENV['SECRET_KEY']
REDIRECT_URI = 'http://localhost:4567/auth/shopify/callback'
SCOPE = 'read_products'

use Rack::Session::Pool, cookie_only: false

get '/login' do
  shop = session[:shop]

  return [403, "Invalid shop parameter (not a myshopify subdomain)"] unless valid_shop?(shop)

  permission_url = 
    "https://#{shop}/admin/oauth/authorize?client_id=#{API_KEY}" \
    "&scope=#{SCOPE}&redirect_uri=#{REDIRECT_URI}"

  redirect permission_url
end

get '/' do
  shop = params[:shop]

  if shop
    clear_session! unless shop == session[:shop]

    session[:shop] = shop
  end

  authenticate! unless authenticated?
  shop = session[:shop]

  # perform an authenticated request to the Shopify API
  response = HTTParty.get(
    "https://#{shop}/admin/products.json",
    :query => { 'limit': 10 },
    :headers => { 'X-SHOPIFY-ACCESS-TOKEN': session[:access_token] },
    :format => :json
  )

  if response.code == 200 
    @products = response['products']
    erb :products
  else
    authenticate!
  end
end

get '/auth/shopify/callback' do
  shop = session[:shop]

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

  session[:access_token] = response['access_token']

  # redirect to the index page
  redirect '/'
end

helpers do
  def authenticated?
    session[:access_token]
  end
  
  def authenticate!
    redirect '/login'
  end
  
  def clear_session!
    session = nil
  end

  def hmac_sign(params, secret)
    params = params.dup
    params.delete('hmac')
  
    # join keys lexicographically
    query = params.map{ |k,v| "#{URI.escape(k.to_s, '&=%')}=#{URI.escape(v.to_s, '&%')}" }.sort.join('&')
  
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret, query)
  end
  
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
end