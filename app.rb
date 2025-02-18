require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get '/' do
  slim :index
end
