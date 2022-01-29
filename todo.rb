require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].message
end

helpers do
  def invalid_name?(str)
    !str.size.between?(1, 100)
  end

  def repeat_list?(str, list)
    list.any? { |todo| todo[:name] == str }
  end

  def error_msg(name, list)
    if invalid_name?(name)
      'List name must have 1 to 100 characters.'
    elsif repeat_list?(name, list)
      'The list name must be unique.'
    end
  end

  def error_msg_todo(name, list)
    if invalid_name?(name)
      'Todo name must have 1 to 100 characters.'
    elsif repeat_list?(name, list)
      'Todo name must be unique.'
    end
  end

  def completed?(list)
    list.all? { |todo| todo[:completed] } if list.size > 0
  end

  def incomplete_by_total(list)
    incomplete = list.count { |todo| !todo[:completed] }
    "#{incomplete}/#{list.size}"
  end

  def sort_lists(lists)
    sorted = lists.partition { |list| !completed?(list[:todos]) }.flatten
    sorted.each { |list| yield list }
  end

  def sort_todos(todos)
    sorted = todos.partition { |todo| !todo[:completed] }.flatten
    sorted.each { |todo| yield todo }
  end
end

get '/' do
  redirect '/lists'
end

# View the lists
get '/lists' do
  @lists = @storage.all_lists

  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_msg(list_name, @storage.all_lists)

  if error
    session[:flash_error] = error
    redirect '/lists/new'
  else
    @storage.add_list(list_name)
    session[:flash_success] = "The list #{list_name} has been created."
    redirect '/lists'
  end
end

get '/lists/:list_id' do
  list_idx = params['list_id'].to_i
  @list = @storage.find_list(list_idx)

  if @list
    erb :single_list, layout: :layout
  else
    session[:flash_error] = "The requested list is not found."
    redirect '/lists'
  end
end

# Delete a list
post '/lists/:list_id/delete' do
  list_idx = params['list_id'].to_i
  lists = @storage.all_lists
  list = lists[list_idx]

  @storage.delete_at(list_idx)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists'
  else
    session[:flash_success] = "The list #{list[:name]} has been deleted."
    redirect '/lists'
  end
end

# Render the edit list page
get '/lists/:list_id/edit' do
  list_id = params['list_id'].to_i
  @list = @storage.find_list(list_id)

  erb :edit_list, layout: :layout
end

# Edit the list
post '/lists/:list_id' do
  list_index = params['list_id'].to_i
  list_name = params[:list_name].strip
  
  list = @storage.find_list(list_index)
  error = error_msg(list_name, @storage.all_lists)

  # if the name is unchanged, redirect to the list
  if list_name == list[:name]
    redirect "/lists/#{list_index}"
  elsif error
    session[:flash_error] = error
    redirect "/lists/#{list_index}/edit"
  else
    @storage.edit_list_name(list_index, list_name)
    session[:flash_success] = "The list #{list[:name]} has been updated."
    redirect "/lists"
  end
end

# Add new todos to the list
post '/lists/:list_id/todos' do
  list_index = params['list_id'].to_i
  todo_item = params[:todo].strip

  list = @storage.find_list(list_index)
  error = error_msg_todo(todo_item, list[:todos])

  if error
    session[:flash_error] = error
    redirect "/lists/#{list_index}"
  else
    @storage.create_new_todo(list_index, todo_item)
 
    session[:flash_success] = "A todo item '#{todo_item}' has been added."
    redirect "/lists/#{list_index}"
  end
end

# Delete a todo from the list
post '/lists/:list_id/todos/:item_id/delete' do
  list_index = params['list_id'].to_i
  item_id = params['item_id'].to_i

  @storage.delete_todo(list_index, item_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:flash_success] = "A todo item has been deleted."
    redirect "/lists/#{list_index}"
  end
end

# Mark todo as complete
post '/lists/:list_id/todos/:item_id' do
  list_id = params['list_id'].to_i
  item_id = params['item_id'].to_i
  is_complete = params[:completed] == 'true'

  @storage.mark_todo_complete(list_id, item_id, is_complete)

  redirect "/lists/#{list_id}"
end

# Mark all todos as complete
post "/lists/:list_id/todos/all/" do
  list_index = params['list_id'].to_i

  @storage.mark_all_todos_complete(list_index)

  session[:flash_success] = "All tasks have been marked complete."
  redirect "/lists/#{list_index}"
end


