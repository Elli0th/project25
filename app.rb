require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader' if development?
require 'bcrypt'

# Enable sessions
enable :sessions

set :session_secret, '7a6238b91650180c4a718d25f8faca5b64f0a2b41dc02bb8769c0bf8cc72d10f4393536375a41faaedeb0972827d8449e8b68358eb90b25f8fc6fa6f1375240b'

# Set public folder
set :public_folder, File.dirname(__FILE__) + '/public'

# Home page route
get '/' do
  slim :index
end

# Login route
post '/login' do
  username = params[:username]
  password = params[:password]
  
  begin
    db = SQLite3::Database.new('db/slutprojekt_db_2025.db')
    db.results_as_hash = true
    
    # Find user by username
    query = "SELECT * FROM User WHERE Username = '#{username}'"
    user = db.execute(query).first
    
    if user && BCrypt::Password.new(user['Password']) == password
      # Set session
      session[:user_id] = user['id']
      session[:username] = user['Username']
      
      # Set cookie for JavaScript to check
      response.set_cookie('user_logged_in', {
        value: true,
        path: '/',
        max_age: 86400 # 1 day
      })
      
      redirect '/budget'
    else
      @login_error = "Felaktigt användarnamn eller lösenord"
      slim :index
    end
  ensure
    db.close if db
  end
end

# Signup route
post '/signup' do
  username = params[:username]
  password = params[:password]
  confirm_password = params[:confirm_password]
  
  # Validate input
  if password != confirm_password
    @signup_error = "Lösenorden matchar inte"
    return slim :index
  end
  
  if username.empty? || password.empty?
    @signup_error = "Alla fält måste fyllas i"
    return slim :index
  end
  
  # Hash the password
  password_hash = BCrypt::Password.create(password)
  
  begin
    db = SQLite3::Database.new('db/slutprojekt_db_2025.db')
    db.results_as_hash = true
    
    # Check if username already exists
    existing_query = "SELECT COUNT(*) as count FROM User WHERE Username = '#{username}'"
    existing_user = db.execute(existing_query).first
    
    if existing_user['count'] > 0
      @signup_error = "Användarnamnet är redan taget"
      return slim :index
    end
    
    # Create new user
    insert_query = "INSERT INTO User (Username, Password) VALUES ('#{username}', '#{password_hash}')"
    db.execute(insert_query)
    
    # Get the new user's ID
    new_user_id = db.last_insert_row_id
    
    # Set session
    session[:user_id] = new_user_id
    session[:username] = username
    
    # Set cookie for JavaScript to check
    response.set_cookie('user_logged_in', {
      value: true,
      path: '/',
      max_age: 86400 # 1 day
    })
    
    redirect '/budget'
  rescue SQLite3::Exception => e
    @signup_error = "Ett fel uppstod: #{e.message}"
    slim :index
  ensure
    db.close if db
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
end

# Protect routes that require authentication
before '/budget' do
  redirect '/' unless logged_in?
end

before '/public_budgets' do
  redirect '/' unless logged_in?
end

# Budget routes
get '/budget' do
  redirect '/' unless logged_in?
  
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  db.results_as_hash = true
  
  # Get budget items with their public status
  current_user_id = session[:user_id]
  
  @budgets = db.execute(<<-SQL
    SELECT b.*, 
           CASE WHEN p.id IS NOT NULL THEN 1 ELSE 0 END AS is_public
    FROM Budget b
    LEFT JOIN Permissions p ON b.id = p.budget_id AND p.user_id = 0
    WHERE b.user_id = #{current_user_id}
  SQL
  )
  
  db.close
    
  slim :budget
end

post '/budget' do
  redirect '/' unless logged_in?
  
  category = params[:category]
  amount = params[:amount].to_i
  is_public = params[:public] ? true : false  # Check if "Offentlig" checkbox is checked
  
  # Get date components
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  # Format the date as YYYY-MM-DD for SQLite
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  current_user_id = session[:user_id]
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  
  begin
    db.transaction
    
    # Insert the budget entry
    db.execute("INSERT INTO Budget (Kategori, Summa, user_id, Datum) VALUES ('#{category}', #{amount}, #{current_user_id}, '#{date}')")
    
    # If it's marked as public, create a permission
    if is_public
      budget_id = db.last_insert_row_id
      db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (#{budget_id}, 0, 'View')")
    end
    
    db.commit
  rescue SQLite3::Exception => e
    db.rollback
    puts "Error occurred: #{e.message}"
  ensure
    db.close
  end
  
  redirect '/budget'
end

# Delete budget route - add this after your existing budget routes
post '/budget/:id/delete' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  
  begin
    # First verify the budget belongs to current user
    owner_check = db.get_first_value("SELECT user_id FROM Budget WHERE id = #{budget_id}")
    
    if owner_check.to_i == current_user_id
      db.transaction
      
      # Delete any permissions first
      db.execute("DELETE FROM Permissions WHERE budget_id = #{budget_id}")
      
      # Then delete the budget item
      db.execute("DELETE FROM Budget WHERE id = #{budget_id} AND user_id = #{current_user_id}")
      
      db.commit
    else
      session[:error] = "Du har inte behörighet att ta bort denna budgetpost"
    end
  rescue SQLite3::Exception => e
    db.rollback if db.transaction_active?
    session[:error] = "Ett fel uppstod: #{e.message}"
  ensure
    db.close if db
  end
  
  redirect '/budget'
end

# Edit budget form route
get '/budget/:id/edit' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  db.results_as_hash = true
  
  begin
    # First check if this budget belongs to the current user
    @budget = db.execute("SELECT * FROM Budget WHERE id = #{budget_id} AND user_id = #{current_user_id}").first
    
    if @budget.nil?
      session[:error] = "Du har inte behörighet att redigera denna budgetpost"
      redirect '/budget'
    end
    
    # Check if this budget is public
    is_public_check = db.get_first_value("SELECT COUNT(*) FROM Permissions WHERE budget_id = #{budget_id} AND user_id = 0")
    @is_public = (is_public_check.to_i > 0)
    
    # Get date components
    date_parts = @budget['Datum'].split('-')
    @year = date_parts[0].to_i
    @month = date_parts[1].to_i
    @day = date_parts[2].to_i
    
    # For date selector
    current_year = Time.now.year
    @years = (current_year-5..current_year+5).to_a
    
  rescue SQLite3::Exception => e
    session[:error] = "Ett fel uppstod: #{e.message}"
    redirect '/budget'
  ensure
    db.close if db
  end
  
  slim :edit_budget
end

# Update budget route
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
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  
  begin
    # First verify the budget belongs to current user
    owner_check = db.get_first_value("SELECT user_id FROM Budget WHERE id = #{budget_id}")
    
    if owner_check.to_i == current_user_id
      db.transaction
      
      # Update the budget entry
      db.execute("UPDATE Budget SET Kategori = '#{category}', Summa = #{amount}, Datum = '#{date}' WHERE id = #{budget_id}")
      
      # Handle public/private status
      public_exists = db.get_first_value("SELECT COUNT(*) FROM Permissions WHERE budget_id = #{budget_id} AND user_id = 0")
      
      if is_public && public_exists.to_i == 0
        # Add public permission
        db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (#{budget_id}, 0, 'View')")
      elsif !is_public && public_exists.to_i > 0
        # Remove public permission
        db.execute("DELETE FROM Permissions WHERE budget_id = #{budget_id} AND user_id = 0")
      end
      
      db.commit
    else
      session[:error] = "Du har inte behörighet att uppdatera denna budgetpost"
    end
  rescue SQLite3::Exception => e
    db.rollback if db.transaction_active?
    session[:error] = "Ett fel uppstod: #{e.message}"
  ensure
    db.close if db
  end
  
  redirect '/budget'
end

# Public budgets route
get '/public_budgets' do
  redirect '/' unless logged_in?
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  db.results_as_hash = true
  
  @public_budgets = db.execute(<<-SQL
    SELECT b.*, u.Username
    FROM Budget b
    JOIN Permissions p ON b.id = p.budget_id AND p.user_id = 0
    JOIN User u ON b.user_id = u.id
    ORDER BY b.Datum DESC
  SQL
  )
  
  db.close
  
  slim :public_budgets
end

# Toggle visibility route
post '/toggle_visibility/:id' do
  redirect '/' unless logged_in?
  
  budget_id = params[:id].to_i
  current_user_id = session[:user_id]
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db', { timeout: 5000 })
  
  begin
    # Check if this budget belongs to the current user
    owner_check = db.get_first_value("SELECT COUNT(*) FROM Budget WHERE id = #{budget_id} AND user_id = #{current_user_id}")
    
    if owner_check.to_i > 0
      # Check if this budget already has a public permission
      public_exists = db.get_first_value("SELECT id FROM Permissions WHERE budget_id = #{budget_id} AND user_id = 0")
      
      if public_exists
        # Remove public permission (make private)
        db.execute("DELETE FROM Permissions WHERE budget_id = #{budget_id} AND user_id = 0")
      else
        # Add public permission (make public)
        db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (#{budget_id}, 0, 'View')")
      end
    end
  rescue SQLite3::Exception => e
    puts "Error occurred: #{e.message}"
  ensure
    db.close
  end
  
  redirect '/budget'
end