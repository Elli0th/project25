# Provides a model layer for the Budget application with database operations and business logic.
# This module follows the module pattern, where each method is mixed into the controller.

require 'sqlite3'
require 'bcrypt'

module Model
  DB_PATH = 'db/slutprojekt_db_2025.db'
  
  # User Authentication Methods
  
  # Authenticates a user with the given credentials
  #
  # @param username [String] the user's username
  # @param password [String] the user's plaintext password
  # @return [Hash, nil] the user record if authentication succeeds, nil otherwise
  def authenticate_user(username, password)
    db = open_db_connection
    
    begin
      query = "SELECT * FROM User WHERE Username = ?"
      user = db.execute(query, [username]).first
      
      if user && BCrypt::Password.new(user['Password']) == password
        return user
      else
        return nil
      end
    ensure
      db.close if db
    end
  end
  
  # Registers a new user with the given credentials
  #
  # @param username [String] the desired username
  # @param password [String] the plaintext password
  # @return [Hash] result hash with keys :success, :error (if failed), :user_id and :username (if successful)
  def register_user(username, password)
    if username.empty? || password.empty?
      return { success: false, error: "Alla fält måste fyllas i" }
    end
    
    password_hash = BCrypt::Password.create(password)
    
    db = open_db_connection
    
    begin
      existing_query = "SELECT COUNT(*) as count FROM User WHERE Username = ?"
      existing_user = db.execute(existing_query, [username]).first
      
      if existing_user['count'] > 0
        return { success: false, error: "Användarnamnet är redan taget" }
      end
      
      insert_query = "INSERT INTO User (Username, Password) VALUES (?, ?)"
      db.execute(insert_query, [username, password_hash])
      
      new_user_id = db.last_insert_row_id
      
      return { success: true, user_id: new_user_id, username: username }
    rescue SQLite3::Exception => e
      return { success: false, error: "Ett fel uppstod: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Budget Methods
  
  # Retrieves all budget items for a specific user
  #
  # @param user_id [Integer] the ID of the user
  # @return [Array<Hash>] array of budget items with public status
  def get_budgets_for_user(user_id)
    db = open_db_connection
    db.results_as_hash = true
    
    begin
      budgets = db.execute(<<-SQL, [user_id])
        SELECT b.*, 
               CASE WHEN p.id IS NOT NULL THEN 1 ELSE 0 END AS is_public
        FROM Budget b
        LEFT JOIN Permissions p ON b.id = p.budget_id AND p.user_id = 0
        WHERE b.user_id = ?
      SQL
      
      return budgets
    ensure
      db.close if db
    end
  end
  
  # Creates a new budget item
  #
  # @param user_id [Integer] the ID of the user creating the budget item
  # @param category [String] the budget category
  # @param amount [Numeric] the budget amount
  # @param date [String] the budget date in YYYY-MM-DD format
  # @param is_public [Boolean] whether the budget item should be public
  # @return [Hash] result hash with keys :success, :error (if failed), :budget_id (if successful)
  def create_budget_item(user_id, category, amount, date, is_public)
    db = open_db_connection
    
    begin
      db.transaction
      
      db.execute("INSERT INTO Budget (Kategori, Summa, user_id, Datum) VALUES (?, ?, ?, ?)", 
        [category, amount, user_id, date])
      
      budget_id = db.last_insert_row_id
      
      if is_public
        db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (?, 0, 'View')", 
          [budget_id])
      end
      
      db.commit
      return { success: true, budget_id: budget_id }
    rescue SQLite3::Exception => e
      db.rollback if db.transaction_active?
      return { success: false, error: "Error occurred: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Deletes a budget item
  #
  # @param budget_id [Integer] the ID of the budget to delete
  # @param user_id [Integer] the ID of the user making the request
  # @return [Hash] result hash with keys :success and :error (if failed)
  def delete_budget_item(budget_id, user_id)
    db = open_db_connection
    
    begin
      owner_check = db.get_first_value("SELECT user_id FROM Budget WHERE id = ?", [budget_id])
      
      if owner_check.to_i != user_id
        return { success: false, error: "Du har inte behörighet att ta bort denna budgetpost" }
      end
      
      db.transaction
      
      db.execute("DELETE FROM Permissions WHERE budget_id = ?", [budget_id])
      db.execute("DELETE FROM Budget WHERE id = ? AND user_id = ?", [budget_id, user_id])
      
      db.commit
      return { success: true }
    rescue SQLite3::Exception => e
      db.rollback if db.transaction_active?
      return { success: false, error: "Ett fel uppstod: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Retrieves a specific budget item
  #
  # @param budget_id [Integer] the ID of the budget to retrieve
  # @param user_id [Integer] the ID of the user making the request
  # @return [Hash] result hash with keys :success, :error (if failed), 
  #                :budget and :is_public (if successful)
  def get_budget_item(budget_id, user_id)
    db = open_db_connection
    db.results_as_hash = true
    
    begin
      budget = db.execute("SELECT * FROM Budget WHERE id = ? AND user_id = ?", [budget_id, user_id]).first
      
      if budget.nil?
        return { success: false, error: "Du har inte behörighet att redigera denna budgetpost" }
      end
      
      is_public_check = db.get_first_value("SELECT COUNT(*) FROM Permissions WHERE budget_id = ? AND user_id = 0", [budget_id])
      is_public = (is_public_check.to_i > 0)
      
      return { success: true, budget: budget, is_public: is_public }
    rescue SQLite3::Exception => e
      return { success: false, error: "Ett fel uppstod: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Updates a budget item
  #
  # @param budget_id [Integer] the ID of the budget to update
  # @param user_id [Integer] the ID of the user making the request
  # @param category [String] the updated budget category
  # @param amount [Numeric] the updated budget amount
  # @param date [String] the updated budget date in YYYY-MM-DD format
  # @param is_public [Boolean] whether the budget item should be public
  # @return [Hash] result hash with keys :success and :error (if failed)
  def update_budget_item(budget_id, user_id, category, amount, date, is_public)
    db = open_db_connection
    
    begin
      owner_check = db.get_first_value("SELECT user_id FROM Budget WHERE id = ?", [budget_id])
      
      if owner_check.to_i != user_id
        return { success: false, error: "Du har inte behörighet att uppdatera denna budgetpost" }
      end
      
      db.transaction
      
      db.execute("UPDATE Budget SET Kategori = ?, Summa = ?, Datum = ? WHERE id = ?", 
                 [category, amount, date, budget_id])
      
      public_exists = db.get_first_value("SELECT COUNT(*) FROM Permissions WHERE budget_id = ? AND user_id = 0", [budget_id])
      
      if is_public && public_exists.to_i == 0
        db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (?, 0, 'View')", [budget_id])
      elsif !is_public && public_exists.to_i > 0
        db.execute("DELETE FROM Permissions WHERE budget_id = ? AND user_id = 0", [budget_id])
      end
      
      db.commit
      return { success: true }
    rescue SQLite3::Exception => e
      db.rollback if db.transaction_active?
      return { success: false, error: "Ett fel uppstod: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Toggles the visibility of a budget item between public and private
  #
  # @param budget_id [Integer] the ID of the budget to toggle
  # @param user_id [Integer] the ID of the user making the request
  # @return [Hash] result hash with keys :success, :error (if failed), :is_public (if successful)
  def toggle_budget_visibility(budget_id, user_id)
    db = open_db_connection
    
    begin
      owner_check = db.get_first_value("SELECT COUNT(*) FROM Budget WHERE id = ? AND user_id = ?", [budget_id, user_id])
      
      if owner_check.to_i == 0
        return { success: false, error: "Du har inte behörighet att ändra denna budgetpost" }
      end
      
      public_exists = db.get_first_value("SELECT id FROM Permissions WHERE budget_id = ? AND user_id = 0", [budget_id])
      
      if public_exists
        db.execute("DELETE FROM Permissions WHERE budget_id = ? AND user_id = 0", [budget_id])
        return { success: true, is_public: false }
      else
        db.execute("INSERT INTO Permissions (budget_id, user_id, permission_type) VALUES (?, 0, 'View')", [budget_id])
        return { success: true, is_public: true }
      end
    rescue SQLite3::Exception => e
      return { success: false, error: "Ett fel uppstod: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Retrieves all public budget items
  #
  # @return [Array<Hash>] array of public budget items with user information
  def get_public_budgets
    db = open_db_connection
    db.results_as_hash = true
    
    begin
      public_budgets = db.execute(<<-SQL)
        SELECT b.*, u.Username
        FROM Budget b
        JOIN Permissions p ON b.id = p.budget_id AND p.user_id = 0
        JOIN User u ON b.user_id = u.id
        ORDER BY b.Datum DESC
      SQL
      
      return public_budgets
    ensure
      db.close if db
    end
  end
  
  # Admin Methods
  
  # Authenticates an admin user with the given credentials
  #
  # @param username [String] the admin's username
  # @param password [String] the admin's plaintext password
  # @return [Hash, nil] the admin user record if authentication succeeds, nil otherwise
  def authenticate_admin(username, password)
    db = open_db_connection
    db.results_as_hash = true
    
    begin
      query = "SELECT * FROM User WHERE Username = ? AND is_admin = 1"
      user = db.execute(query, [username]).first
      
      if user && BCrypt::Password.new(user['Password']) == password
        return user
      else
        return nil
      end
    ensure
      db.close if db
    end
  end
  
  # Creates a new admin user
  #
  # @param username [String] the desired admin username
  # @param password [String] the plaintext password
  # @return [Hash] result hash with keys :success and :error (if failed)
  def create_admin_user(username, password)
    if username.empty? || password.empty?
      return { success: false, error: "Username and password are required" }
    end
    
    password_hash = BCrypt::Password.create(password)
    
    db = open_db_connection
    
    begin
      db.results_as_hash = true
      
      begin
        db.execute("SELECT is_admin FROM User LIMIT 1")
      rescue SQLite3::Exception
        db.execute("ALTER TABLE User ADD COLUMN is_admin INTEGER DEFAULT 0")
      end
      
      username_check = db.execute("SELECT COUNT(*) FROM User WHERE Username = ?", [username])
      count = username_check[0][0].to_i
      
      if count > 0
        return { success: false, error: "Username already taken" }
      end
      
      db.execute("INSERT INTO User (Username, Password, is_admin) VALUES (?, ?, 1)", 
                 [username, password_hash])
      
      return { success: true }
    rescue SQLite3::Exception => e
      return { success: false, error: "Error: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  # Retrieves all users in the system
  #
  # @return [Array<Hash>] array of user records with id, username, and admin status
  def get_all_users
    db = open_db_connection
    db.results_as_hash = true
    
    begin
      users = db.execute("SELECT id, Username, is_admin FROM User ORDER BY Username")
      return users
    ensure
      db.close if db
    end
  end
  
  # Deletes a user account and all associated data
  #
  # @param user_id [Integer] the ID of the user to delete
  # @param admin_id [Integer] the ID of the admin making the request
  # @return [Hash] result hash with keys :success and :error (if failed)
  def delete_user(user_id, admin_id)
    if user_id == admin_id
      return { success: false, error: "You cannot delete your own admin account" }
    end
    
    db = open_db_connection
    
    begin
      db.transaction
      
      db.execute("DELETE FROM Permissions WHERE user_id = ?", [user_id])
      db.execute("DELETE FROM Budget WHERE user_id = ?", [user_id])
      db.execute("DELETE FROM User WHERE id = ?", [user_id])
      
      db.commit
      return { success: true }
    rescue SQLite3::Exception => e
      db.rollback if db.transaction_active?
      return { success: false, error: "Error: #{e.message}" }
    ensure
      db.close if db
    end
  end
  
  private
  
  # Opens a connection to the SQLite database
  def open_db_connection
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true
    return db
  end
end