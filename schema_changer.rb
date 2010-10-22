#!/usr/bin/env ruby

# TODO: currently assumes we are always adding a column

require 'rubygems'
require 'active_wrapper'

class SchemaChanger
  def initialize
    @db, @log, @mail = ActiveWrapper.setup(
      :base => File.expand_path("..", __FILE__),
      :env => ENV['RAILS_ENV'] || 'development',
      :log => "schema_changer"
    )
    @db.establish_connection
    @conn = ActiveRecord::Base.connection
  end
  
  def run
    ask "What is the name of the table you want to alter?"
    @table = gets
    @old_table = @table
    @new_table = "#{@table}_new"
    @model = Object.const_set(@old_table.classify, Class.new(ActiveRecord::Base))
    ask "What do you want to do to the table? [add_index, add_column]"
    @action = parse_action
    ask "What is the modification to the table?"
    ask "Examples: ADD COLUMN teaser_lock tinyint(1) DEFAULT '0'"
    ask "          ADD INDEX slide_id (slide_id)"
    @mod = parse_mod
    @sql = {}
  end
  
  # the parameter is only for testing
  def gets(name = nil)
    STDIN.gets.strip
  end
  
  def make_new
    @sql[:create] = %{CREATE TABLE #{@new_table} LIKE #{@old_table}}
    if @action == 'add_column'
      @sql[:mod] = %{ALTER TABLE #{@new_table} #{@mod}}
    elsif @action == 'add_index'
      @sql[:mod] = %{ALTER TABLE #{@new_table} #{@mod}}
    end
  end
  
  def base_sync
    lower = 1
    upper = 10
    new_column_default = ", 0 AS teaser_lock" # TODO: 
    set_columns = @model.column_names.collect{|x| "new.#{x} = old.new#{x}" }.join(", ")
    @sql[:base_sync] = %Q{
      INSERT INTO articles_new (
        SELECT
      	  #{new_column_default}
      	FROM #{@old_table} WHERE id >= #{lower} AND id <= #{upper}
      )
    }
  end
  
  def final_sync
    
  end
  
  def rename
    
  end
  
  # returns Array of record ids
  def find(table, cond)
    sql = "SELECT id FROM #{table} WHERE #{cond}"
    response = @conn.execute(sql)
    results = []
    while row = response.fetch_row do
      results << row[0].to_i
    end
    results
  end
  
  # lower memory heavy version of ActiveRecord's find in batches
  def find_in_batches(table, options = {})
    raise "You can't specify an order, it's forced to be #{batch_order}" if options[:order]
    raise "You can't specify a limit, it's forced to be the batch_size"  if options[:limit]

    start = options.delete(:start).to_i
    batch_size = options.delete(:batch_size) || 1000
    order_limit = "ORDER BY id LIMIT #{batch_size}"

    records = find(table, "id >= #{start} #{order_limit}")
    while records.any?
      yield records

      break if records.size < batch_size
      records = find(table, "id > #{records.last} #{order_limit}")
    end
  end
  
private
  def ask(msg)
    puts msg
  end

  def parse_action
    action = gets.downcase
  end
  
  # raw: teaser_lock tinyint(1) DEFAULT '0'
  def parse_mod
    column = STDIN.gets.strip
  end

end

