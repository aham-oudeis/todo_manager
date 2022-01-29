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
    sql = <<~SQL
        SELECT list.*, 
               count(todo.id) AS total_todos_count,
               count(NULLIF(todo.completed, true)) AS incomplete_todos_count
          FROM list
     LEFT JOIN todo
            ON todo.list_id = list.id
      GROUP BY list.id
      ORDER BY list.name;
    SQL

    result = query(sql)

    result.map do |tuple|
      {id: tuple["id"],
       name: tuple["name"],
       total_todos_count: tuple['total_todos_count'].to_i,
       incomplete_todos_count: tuple['incomplete_todos_count'].to_i
      }
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
    sql = <<~SQL
      SELECT todo.id AS todo_id,
            todo.name AS todo_name,
            todo.completed,
            list.id AS list_id,
            list.name AS list_name
        FROM todo
        JOIN list
          ON todo.list_id = list.id
       WHERE list.id = $1;
    SQL

    result = query(sql, id)

    list_id = result.field_values('list_id')[0]
    list_name = result.field_values('list_name')[0]

    return nil if list_id.nil?
    total_todos_count = result.ntuples
    incomplete_todos_count = result.field_values('completed').count { |item| item == 'f' }
  
    todos = find_todos(result)

    { id:list_id.to_i,
      name: list_name,
      todos: todos,
      total_todos_count: total_todos_count,
      incomplete_todos_count: incomplete_todos_count }
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

  def find_todos(result)
    result.map do |tuple| 
      { id: tuple['todo_id'].to_i,
        name: tuple['todo_name'],
        completed: to_boolean(tuple['completed'])
      }
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
