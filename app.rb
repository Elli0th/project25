# Budget application main controller
# Handles HTTP requests and responses using the Sinatra framework

require 'sinatra'
require 'slim'
require 'sinatra/reloader' if development?
require_relative 'model/model'

# Enable sessions
enable :sessions

set :session_secret, '7a6238b91650180c4a718d25f8faca5b64f0a2b41dc02bb8769c0bf8cc72d10f4393536375a41faaedeb0972827d8449e8b68358eb90b25f8fc6fa6f1375240b'

# Set public folder
set :public_folder, File.dirname(__FILE__) + '/public'

# Include the Model module
include Model

# Home page route
get '/' do
  slim :home
end

# Login page route
get '/login' do
  redirect '/' if logged_in?
  slim :user_login
end

# Process login form submission
post '/login' do
  username = params[:username]
  password = params[:password]
  
  user = authenticate_user(username, password)
  
  if user
    session[:user_id] = user['id']
    session[:username] = user['Username']
    
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400
    })
    
    redirect '/'
  else
    @login_error = "Felaktigt användarnamn eller lösenord"
    slim :user_login
  end
end

# Registration page route
get '/register' do
  redirect '/' if logged_in?
  slim :user_register
end

# Process registration form submission
post '/signup' do
  username = params[:username]
  password = params[:password]
  confirm_password = params[:confirm_password]
  
  if password != confirm_password
    @signup_error = "Lösenorden matchar inte"
    return slim :user_register
  end
  
  result = register_user(username, password)
  
  if result[:success]
    session[:user_id] = result[:user_id]
    session[:username] = result[:username]
    
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400
    })
    
    redirect '/'
  else
    @signup_error = result[:error]
    slim :user_register
  end
end

# Logout route
get '/logout' do
  session.clear
  response.delete_cookie('user_logged_in')
  redirect '/'
end

# Authentication helper methods
helpers do
  def logged_in?
    !session[:user_id].nil?
  end
  
  def current_user
    session[:user_id]
  end
  
  def is_admin?
    session[:is_admin] == true
  end

  def require_admin
    redirect '/' unless logged_in? && is_admin?
  end
end

# Protect routes that require authentication
before '/budget' do
  redirect '/' unless logged_in?
end

before '/public_budgets' do
  redirect '/' unless logged_in?
end

# Budget routes

# View all budget items for current user
get '/budget' do
  redirect '/' unless logged_in?
  
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  
  current_user_id = session[:user_id]
  @budgets = get_budgets_for_user(current_user_id)
    
  slim :budget
end

# Create a new budget item
post '/budget' do
  redirect '/' unless logged_in?
  
  category = params[:category]
  amount = params[:amount].to_i
  is_public = params[:public] ? true : false
  
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  
  result = create_budget_item(session[:user_id], category, amount, date, is_public)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Delete a budget item
post '/budget/:id/delete' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = delete_budget_item(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Edit budget form route
get '/budget/:id/edit' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = get_budget_item(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
    redirect '/budget'
  end
  
  @budget = result[:budget]
  @is_public = result[:is_public]
  
  date_parts = @budget['Datum'].split('-')
  @year = date_parts[0].to_i
  @month = date_parts[1].to_i
  @day = date_parts[2].to_i
  
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  
  slim :edit_budget
end

# Update a budget item
post '/budget/:id/update' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  category = params[:category]
  amount = params[:amount].to_f
  is_public = params[:public] ? true : false
  
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  
  result = update_budget_item(budget_id, current_user_id, category, amount, date, is_public)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Public budgets route
get '/public_budgets' do
  redirect '/' unless logged_in?
  
  @public_budgets = get_public_budgets
  
  slim :public_budgets
end

# Toggle budget visibility
post '/toggle_visibility/:id' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = toggle_budget_visibility(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Admin routes

# Admin login page
get '/admin' do
  redirect '/' if logged_in? && !is_admin?
  slim :admin_login
end

# Process admin login
post '/admin/login' do
  username = params[:username]
  password = params[:password]
  
  user = authenticate_admin(username, password)
  
  if user
    session[:user_id] = user['id']
    session[:username] = user['Username']
    session[:is_admin] = true
    
    redirect '/admin/dashboard'
  else
    @login_error = "Invalid admin credentials"
    slim :admin_login
  end
end

# Admin dashboard
get '/admin/dashboard' do
  require_admin
  
  @users = get_all_users
  
  slim :admin_dashboard
end

# Delete a user (admin only)
post '/admin/users/:id/delete' do
  require_admin
  
  user_id = params[:id].to_i
  admin_id = session[:user_id]
  
  result = delete_user(user_id, admin_id)
  
  if result[:success]
    session[:success] = "User account deleted successfully"
  else
    session[:error] = result[:error]
  end
  
  redirect '/admin/dashboard'
end

# Admin setup page
get '/setup/admin' do
  slim :create_admin
end

# Process admin creation
post '/setup/admin' do
  username = params[:username]
  password = params[:password]
  admin_key = params[:admin_key]
  
  if admin_key != "NoIjKY8It2eu1xURfwGx"
    @error = "Invalid admin setup key"
    return slim :create_admin
  end
  
  result = create_admin_user(username, password)
  
  if result[:success]
    @success = "Admin account created successfully"
  else
    @error = result[:error]
  end
  
  slim :create_admin
end