require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
    @logger = logger
  end

  def all_lists
    sql = "SELECT * FROM list;"
    result = query(sql)

    result.map do |tuple|
      {id: tuple["id"], name: tuple["name"], todos: find_todos(tuple["id"]) }
    end
  end

  def contains?(list_id)
    sql = "SELECT * FROM list WHERE id = $1"
    result = query(sql, list_id)
    result.ntuples != 0
  end

  def add_list(list_name)
    sql = "INSERT INTO list (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_at(id)
    sql = "DELETE FROM list WHERE id = $1;"
    query(sql, id)
  end

  def find_list(id)
    sql = "SELECT id, name FROM list WHERE id = $1;"
    result = query(sql, id)

    list_id_name = result.map { |tuple| [tuple['id'], tuple['name']] }.flatten

    return nil if list_id_name.empty?
  
    todos = find_todos(id)

    {id:list_id_name.first, name: list_id_name.last, todos: todos }
  end

  def edit_list_name(list_id, list_name)
    sql = "UPDATE list SET name = $1 WHERE id = $2;"
    query(sql, list_name, list_id)
  end

  def create_new_todo(list_id, todo_item)
    sql = "INSERT INTO todo (name, list_id, completed) VALUES ($1, $2, false);"
    query(sql, todo_item, list_id)
  end

  def delete_todo(list_id, item_id)
    sql = "DELETE FROM todo WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, item_id)
  end

  def mark_todo_complete(list_id, item_id, is_complete)
    sql = "UPDATE todo SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, is_complete, list_id, item_id)
  end

  def mark_all_todos_complete(list_id)
    sql = "UPDATE todo SET completed = true "\
          "WHERE list_id = $1"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def find_todos(list_id)
    sql = "SELECT id, name, completed FROM todo WHERE list_id = $1 ORDER BY id;"
    result = query(sql, list_id)
  
    result.map do |tuple| 
      {id: tuple['id'].to_i, name: tuple['name'], completed: to_boolean(tuple['completed'])}
    end
  end

  def to_boolean(str)
    str == 't'
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end
end
