# @title Budget Application Controller
# @author Ellioth Nyman
#
# Budget application main controller
# Handles HTTP requests and responses using the Sinatra framework

require 'sinatra'
require 'slim'
require 'sinatra/reloader' if development?
require_relative 'model/model'

# Enable sessions
enable :sessions

# Set public folder
set :public_folder, File.dirname(__FILE__) + '/public'

# Include the Model module
include Model

# Home page route
# Displays the welcome page with login/registration options
#
# @route GET /
# @return [String] rendered home page template
get '/' do
  slim :home
end

# Login page route
# Shows the login form, redirects if already logged in
#
# @route GET /login
# @return [String] rendered login page template
get '/login' do
  redirect '/' if logged_in?
  slim :user_login
end

# Process login form submission
# Authenticates user and creates session
#
# @route POST /login 
# @param username [String] the username from form
# @param password [String] the password from form
# @return [String] rendered login page with error (if failed) or redirect to home (if successful)
post '/login' do
  session[:login_attempts] ||= 0
  session[:last_attempt_time] ||= nil
  cooldown_period = 30 # 30 seconds
  max_attempts = 5

  if session[:login_attempts] >= max_attempts && session[:last_attempt_time] && Time.now.to_i - session[:last_attempt_time] < cooldown_period
    @login_error = "För många misslyckade försök. Vänta ett par sekunder innan du försöker igen."
    return slim :user_login
  end

  username = params[:username]
  password = params[:password]
  user = authenticate_user(username, password)

  if user
    session[:user_id] = user['id']
    session[:username] = user['Username']
    session[:login_attempts] = 0
    session[:last_attempt_time] = nil
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400
    })
    redirect '/'
  else
    session[:login_attempts] += 1
    session[:last_attempt_time] = Time.now.to_i
    @login_error = "Felaktigt användarnamn eller lösenord"
    slim :user_login
  end
end

# Registration page route 
# Shows the user registration form, redirects if already logged in
#
# @route GET /register
# @return [String] rendered registration page template
get '/register' do
  redirect '/' if logged_in?
  slim :user_register
end

# Process registration form submission
# Creates a new user account
#
# @route POST /signup
# @param username [String] the desired username
# @param password [String] the password
# @param confirm_password [String] password confirmation
# @return [String] rendered registration page with error (if failed) or redirect to home (if successful)
post '/signup' do
  username = params[:username]
  password = params[:password]
  confirm_password = params[:confirm_password]
  
  if password != confirm_password
    @signup_error = "Lösenorden matchar inte"
    return slim :user_register
  end
  
  if username.empty? || password.empty?
    @signup_error = "Alla fält måste fyllas i"
    return slim :user_register
  end
  
  if password.length < 6
    @signup_error = "Lösenordet måste vara minst 6 tecken"
    return slim :user_register
  end
  
  result = register_user(username, password)
  
  if result[:success]
    session[:user_id] = result[:user_id]
    session[:username] = result[:username]
    redirect '/'
  else
    @signup_error = result[:error]
    slim :user_register
  end
end

# Logout route
# Clears user session and cookies
#
# @route GET /logout
# @return [nil] redirect to home page
get '/logout' do
  session.clear
  response.delete_cookie('user_logged_in')
  redirect '/'
end

# Authentication helper methods
helpers do
  # Checks if a user is currently logged in
  #
  # @return [Boolean] true if user is logged in, false otherwise
  def logged_in?
    !session[:user_id].nil?
  end
  
  # Gets the current user's ID from session
  #
  # @return [Integer] the ID of the current user
  def current_user
    session[:user_id]
  end
  
  # Checks if the current user is an admin
  #
  # @return [Boolean] true if user is an admin, false otherwise
  def is_admin?
    session[:is_admin] == true
  end

  # Ensures that the current user is an admin, redirects otherwise
  #
  # @return [nil] redirects to home if not admin
  def require_admin
    redirect '/' unless logged_in? && is_admin?
  end
end

# Protect routes that require authentication
# Ensures user is logged in for all budget routes
before '/budgets*' do
  redirect '/' unless logged_in?
end

# Ensures user is logged in for public budgets view
before '/public_budgets' do
  redirect '/' unless logged_in?
end

# Budget routes

# View all budget items for current user
get '/budgets' do
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  current_user_id = session[:user_id]
  @budgets = get_budgets_for_user(current_user_id)
  @categories = get_all_categories
  slim :budget
end

# Create a new budget item
get '/budgets/new' do
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  @categories = get_all_categories
  slim :new_budget
end

# Process new budget item submission
post '/budgets' do
  category_id = params[:category].to_i
  amount = params[:amount].to_i
  is_public = params[:public] ? true : false
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  @categories = get_all_categories
  @years = (Time.now.year-5..Time.now.year+5).to_a

  # Validering
  if category_id == 0 || params[:category].empty? || !@categories.any? { |c| c['id'] == category_id }
    session[:error] = "Du måste välja en giltig kategori."
    return slim :new_budget
  end
  if amount <= 0
    session[:error] = "Beloppet måste vara större än 0."
    return slim :new_budget
  end
  if year == 0 || month == 0 || day == 0
    session[:error] = "Du måste ange ett giltigt datum."
    return slim :new_budget
  end

  result = create_budget_item(session[:user_id], category_id, amount, date, is_public)
  session[:error] = result[:error] unless result[:success]
  redirect '/budgets'
end

# Edit budget form route
get '/budgets/:id/edit' do
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  result = get_budget_item(budget_id, current_user_id)
  if !result[:success]
    session[:error] = result[:error]
    redirect '/budgets'
  end
  @budget = result[:budget]
  @is_public = result[:is_public]
  date_parts = @budget['Datum'].split('-')
  @year = date_parts[0].to_i
  @month = date_parts[1].to_i
  @day = date_parts[2].to_i
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  @categories = get_all_categories
  slim :edit_budget
end

# Update a budget item
patch '/budgets/:id' do
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  category_id = params[:category].to_i
  amount = params[:amount].to_f
  is_public = params[:public] ? true : false
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  @categories = get_all_categories
  @years = (Time.now.year-5..Time.now.year+5).to_a
  @budget = get_budget_item(budget_id, current_user_id)[:budget]
  @is_public = is_public
  # Validering
  if category_id == 0 || params[:category].empty? || !@categories.any? { |c| c['id'] == category_id }
    session[:error] = "Du måste välja en giltig kategori."
    return slim :edit_budget
  end
  if amount <= 0
    session[:error] = "Beloppet måste vara större än 0."
    return slim :edit_budget
  end
  if year == 0 || month == 0 || day == 0
    session[:error] = "Du måste ange ett giltigt datum."
    return slim :edit_budget
  end
  result = update_budget_item(budget_id, current_user_id, category_id, amount, date, is_public)
  session[:error] = result[:error] unless result[:success]
  redirect '/budgets'
end

# Delete a budget item
delete '/budgets/:id' do
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  result = delete_budget_item(budget_id, current_user_id)
  session[:error] = result[:error] unless result[:success]
  redirect '/budgets'
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
  
  redirect '/budgets'
end

# Admin routes

# Admin login page
# Shows the admin login form
#
# @route GET /admin
# @return [String] rendered admin login page template
get '/admin' do
  redirect '/' if logged_in? && !is_admin?
  slim :admin_login
end

# Process admin login
# Authenticates admin user and creates session with admin privileges
#
# @route POST /admin/login
# @param username [String] the admin username
# @param password [String] the admin password
# @return [String] rendered login page with error (if failed) or redirect to admin dashboard (if successful)
post '/admin/login' do
  session[:admin_login_attempts] ||= 0
  session[:admin_last_attempt_time] ||= nil
  cooldown_period = 300 # 5 minuter
  max_attempts = 5

  if session[:admin_login_attempts] >= max_attempts && session[:admin_last_attempt_time] && Time.now.to_i - session[:admin_last_attempt_time] < cooldown_period
    @login_error = "För många misslyckade försök. Vänta några minuter innan du försöker igen."
    return slim :admin_login
  end

  username = params[:username]
  password = params[:password]
  user = authenticate_admin(username, password)

  if user
    session[:user_id] = user['id']
    session[:username] = user['Username']
    session[:is_admin] = true
    session[:admin_login_attempts] = 0
    session[:admin_last_attempt_time] = nil
    redirect '/admin/dashboard'
  else
    session[:admin_login_attempts] += 1
    session[:admin_last_attempt_time] = Time.now.to_i
    @login_error = "Invalid admin credentials"
    slim :admin_login
  end
end

# Admin dashboard
# Displays user management interface for admins
#
# @route GET /admin/dashboard
# @return [String] rendered admin dashboard template with user list
get '/admin/dashboard' do
  require_admin
  
  @users = get_all_users
  
  slim :admin_dashboard
end

# Delete a user (admin only)
# Removes a user account and associated data
#
# @route POST /admin/users/:id/delete
# @param id [Integer] the ID of the user to delete
# @return [nil] redirect to admin dashboard with success/error message
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
# Shows the initial admin creation form
#
# @route GET /setup/admin
# @return [String] rendered admin creation page template
get '/setup/admin' do
  slim :create_admin
end

# Process admin creation
# Creates the initial admin account with the admin key
#
# @route POST /setup/admin
# @param username [String] the desired admin username
# @param password [String] the admin password
# @param admin_key [String] the security key required for admin creation
# @return [String] rendered admin creation page with success/error message
post '/setup/admin' do
  username = params[:username]
  password = params[:password]
  admin_key = params[:admin_key]
  
  if admin_key != "NoIjKY8It2eu1xURfwGx"
    @error = "Invalid admin setup key"
    return slim :create_admin
  end
  
  if username.empty? || password.empty?
    @error = "Alla fält måste fyllas i"
    return slim :create_admin
  end
  
  if password.length < 6
    @error = "Lösenordet måste vara minst 6 tecken"
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