# Budget application main controller
# Handles HTTP requests and responses using the Sinatra framework

require 'sinatra'
require 'slim'
require 'sinatra/reloader' if development?
require_relative 'model'

# Enable sessions
enable :sessions

set :session_secret, '7a6238b91650180c4a718d25f8faca5b64f0a2b41dc02bb8769c0bf8cc72d10f4393536375a41faaedeb0972827d8449e8b68358eb90b25f8fc6fa6f1375240b'

# Set public folder
set :public_folder, File.dirname(__FILE__) + '/public'

# Home page route
# @return [String] rendered index template
get '/' do
  slim :index
end

# Login page route
# @return [String] rendered login template or redirect to home
get '/login' do
  redirect '/' if logged_in?
  slim :user_login
end

# Process login form submission
# @return [String] redirect to home or rendered login template with error
post '/login' do
  username = params[:username]
  password = params[:password]
  
  user = BudgetModel.authenticate_user(username, password)
  
  if user
    # Set session
    session[:user_id] = user['id']
    session[:username] = user['Username']
    
    # Set cookie for JavaScript to check
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400 # 1 day
    })
    
    redirect '/'
  else
    @login_error = "Felaktigt användarnamn eller lösenord"
    slim :user_login
  end
end

# Registration page route
# @return [String] rendered registration template or redirect to home
get '/register' do
  redirect '/' if logged_in?
  slim :user_register
end

# Process registration form submission
# @return [String] redirect to home or rendered registration template with error
post '/signup' do
  username = params[:username]
  password = params[:password]
  confirm_password = params[:confirm_password]
  
  # Validate input
  if password != confirm_password
    @signup_error = "Lösenorden matchar inte"
    return slim :user_register
  end
  
  result = BudgetModel.register_user(username, password)
  
  if result[:success]
    # Set session
    session[:user_id] = result[:user_id]
    session[:username] = result[:username]
    
    # Set cookie for JavaScript to check
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400 # 1 day
    })
    
    redirect '/'
  else
    @signup_error = result[:error]
    slim :user_register
  end
end

# Logout route
# @return [String] redirect to home
get '/logout' do
  session.clear
  response.delete_cookie('user_logged_in')
  redirect '/'
end

# Authentication helper methods
helpers do
  # Check if a user is logged in
  # @return [Boolean] true if user is logged in, false otherwise
  def logged_in?
    !session[:user_id].nil?
  end
  
  # Get the current user's ID
  # @return [Integer, nil] the current user's ID or nil if not logged in
  def current_user
    session[:user_id]
  end
  
  # Check if current user is an admin
  # @return [Boolean] true if user is admin, false otherwise
  def is_admin?
    session[:is_admin] == true
  end

  # Require admin privileges, redirect if not admin
  # @return [nil]
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
# @return [String] rendered budget template
get '/budget' do
  redirect '/' unless logged_in?
  
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  
  current_user_id = session[:user_id]
  @budgets = BudgetModel.get_budgets_for_user(current_user_id)
    
  slim :budget
end

# Create a new budget item
# @return [String] redirect to budget page
post '/budget' do
  redirect '/' unless logged_in?
  
  category = params[:category]
  amount = params[:amount].to_i
  is_public = params[:public] ? true : false
  
  # Get date components
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  # Format the date as YYYY-MM-DD for SQLite
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  
  result = BudgetModel.create_budget_item(session[:user_id], category, amount, date, is_public)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Delete a budget item
# @return [String] redirect to budget page
post '/budget/:id/delete' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = BudgetModel.delete_budget_item(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Edit budget form route
# @return [String] rendered edit_budget template or redirect to budget
get '/budget/:id/edit' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = BudgetModel.get_budget_item(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
    redirect '/budget'
  end
  
  @budget = result[:budget]
  @is_public = result[:is_public]
  
  # Get date components
  date_parts = @budget['Datum'].split('-')
  @year = date_parts[0].to_i
  @month = date_parts[1].to_i
  @day = date_parts[2].to_i
  
  # For date selector
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  
  slim :edit_budget
end

# Update a budget item
# @return [String] redirect to budget page
post '/budget/:id/update' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  category = params[:category]
  amount = params[:amount].to_f
  is_public = params[:public] ? true : false
  
  # Get date components
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  # Format date
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  
  result = BudgetModel.update_budget_item(budget_id, current_user_id, category, amount, date, is_public)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Public budgets route
# @return [String] rendered public_budgets template
get '/public_budgets' do
  redirect '/' unless logged_in?
  
  @public_budgets = BudgetModel.get_public_budgets
  
  slim :public_budgets
end

# Toggle budget visibility between public and private
# @return [String] redirect to budget page
post '/toggle_visibility/:id' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  result = BudgetModel.toggle_budget_visibility(budget_id, current_user_id)
  
  if !result[:success]
    session[:error] = result[:error]
  end
  
  redirect '/budget'
end

# Admin routes

# Admin login page
# @return [String] rendered admin_login template or redirect
get '/admin' do
  redirect '/' if logged_in? && !is_admin?
  slim :admin_login
end

# Process admin login
# @return [String] redirect to admin dashboard or rendered admin_login with error
post '/admin/login' do
  username = params[:username]
  password = params[:password]
  
  user = BudgetModel.authenticate_admin(username, password)
  
  if user
    # Set session
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
# @return [String] rendered admin_dashboard template
get '/admin/dashboard' do
  require_admin
  
  @users = BudgetModel.get_all_users
  
  slim :admin_dashboard
end

# Delete a user (admin only)
# @return [String] redirect to admin dashboard
post '/admin/users/:id/delete' do
  require_admin
  
  user_id = params[:id].to_i
  admin_id = session[:user_id]
  
  result = BudgetModel.delete_user(user_id, admin_id)
  
  if result[:success]
    session[:success] = "User account deleted successfully"
  else
    session[:error] = result[:error]
  end
  
  redirect '/admin/dashboard'
end

# Admin setup page
# @return [String] rendered create_admin template
get '/setup/admin' do
  slim :create_admin
end

# Process admin creation
# @return [String] rendered create_admin template with success or error
post '/setup/admin' do
  username = params[:username]
  password = params[:password]
  admin_key = params[:admin_key]
  
  # Security check with your provided key
  if admin_key != "NoIjKY8It2eu1xURfwGx"
    @error = "Invalid admin setup key"
    return slim :create_admin
  end
  
  result = BudgetModel.create_admin_user(username, password)
  
  if result[:success]
    @success = "Admin account created successfully"
  else
    @error = result[:error]
  end
  
  slim :create_admin
end