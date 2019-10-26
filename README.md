# shopify-basic-sinatra

This is a basic Sinatra application which demonstrates authenticating with Shopify via OAuth, and performing an authenticated Shopify API request.

This example uses a .env file to store the application credentials. After cloning the repository, you'll need to create a file named .env in the same folder. The contents of the file should be as follows:

API_KEY=YOUR_API_KEY
API_SECRET=YOUR_SECRET_KEY

Where YOUR_API_KEY and YOUR_SECRET_KEY are the values of your application's API key and secret key, obtained from the Shopify Partner Dashboard.

To get started with this example:

1. Create the `.env` file as described above.
2. `bundle install` to obtain all of the necessary dependencies
3. `ruby application.rb` to start the server on port 4567.
4. Visit `htttp://localhost:4567?shop=<your-shop.myshopify.com>` in your browser, subsituting `<your-shop.myshopify.com>` for the `myshopify` domain of your Shopify store. Follow the prompt to authenticate the application with your Shopify store account.
