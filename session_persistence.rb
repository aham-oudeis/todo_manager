
class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def all_lists
    @session[:lists].clone
  end

  def add_list(new_list)
    @session[:lists] << new_list
  end

  def delete_at(index)
    @session[:lists].delete_at(index)
  end

  def [](key)
    @session[key]
  end

  def []=(key, value)
    @session[key] = value
  end

  def delete(key)
    @session.delete(key)
  end

  def find_list(index)
    @session[:lists][index]
  end

  def edit_list_name(list_index, list_name)
    list = @session[:lists][list_index]
    list[:name] = list_name
  end

  def create_new_todo(list_index, todo_item)
    list = @session[:lists][list_index]
    id = next_todo_id(list[:todos])
    list[:todos] << { id: id, name: todo_item, completed: false }
  end

  def delete_todo(list_index, item_id)
    list = @session[:lists][index]
    list[:todos].reject! { |todo| todo[:id] == item_id }
  end

  def mark_todo_complete(list_index, item_id, is_complete)
    list = @session[:lists][list_index]

    list[:todos].each do |todo|
      if todo[:id] == item_id 
        todo[:completed] = is_complete
      end
    end
  end

  def mark_all_todos_complete
    list = @session[:lists][index]

    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  private

  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end
end
