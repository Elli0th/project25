require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

set :public_folder, File.dirname(__FILE__) + '/public'

get '/' do
  slim :index
end

get '/budget' do
  current_year = Time.now.year
  @years = (current_year-5..current_year+5).to_a
  @months = (1..12).to_a
  @days = (1..31).to_a
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db')
  db.results_as_hash = true
  @budgets = db.execute("SELECT * FROM Budget")
  db.close
  
  slim :budget
end

post '/budget' do
  category = params[:category]
  amount = params[:amount].to_i
  
  # Get date components
  year = params[:year].to_i
  month = params[:month].to_i
  day = params[:day].to_i
  
  # Format the date as YYYY-MM-DD for SQLite
  date = "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
  
  db = SQLite3::Database.new('db/slutprojekt_db_2025.db')
  db.execute("INSERT INTO Budget (Kategori, Summa, user_id, Datum) VALUES (?, ?, ?, ?)", 
             [category, amount, 1, date])
  db.close
  
  redirect '/budget'
end