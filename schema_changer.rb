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
    
    @batch_size = 10
  end
  
  def run
    ask "What is the name of the table you want to alter?"
    @table = gets(:table)
    @temp_table = "#{@table}_schema_temp"
    @trash_table = "#{@table}_schema_trash"

    @model = Object.const_set(@table.classify, Class.new(ActiveRecord::Base))
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
  
  def create
    @sql[:create] = %{CREATE TABLE #{@temp_table} LIKE #{@table}}
    if @action == 'add_column'
      @sql[:mod] = %{ALTER TABLE #{@temp_table} #{@mod}}
    elsif @action == 'add_index'
      @sql[:mod] = %{ALTER TABLE #{@temp_table} #{@mod}}
    end
    @conn.execute(@sql[:create])
    @conn.execute(@sql[:mod])
  end
  
  def sync
    start = res = @conn.execute("SELECT max(id) AS max_id FROM `#{@temp_table}`")
    start = res.fetch_row[0].to_i + 1 # nil case is okay: [nil][0].to_i => nil 
    find_in_batches("users", :start => start, :batch_size => @batch_size) do |batch|
      # puts "batch #{batch.inspect}"
      lower = batch.first
      upper = batch.last
      new_column_default = ", 0 AS teaser_lock" # TODO: 
      columns = @model.column_names.join(", ")
      columns += new_column_default
      @sql[:base_sync] = %Q{
        INSERT INTO #{@temp_table} (
          SELECT #{columns}
        	FROM #{@table} WHERE id >= #{lower} AND id <= #{upper}
        )
      }
      puts @sql[:base_sync]
    end
  end
  
  # TODO: updated_at if its available and use a real time vs some guess
  def final_sync
    sync
    columns = @model.column_names.collect{|x| "#{@temp_table}.#{x} = #{@table}.#{x}" }.join(", ")
    sql = %{
      UPDATE #{@temp_table} INNER JOIN #{@table}
        ON #{@temp_table}.id = #{@table}.id
        SET #{columns}
      WHERE #{@table}.updated_at >= '#{1.day.ago.strftime("%Y-%m-%d")}'
    }
    puts sql
  end
  
  def switch
    final_sync
    puts to_old   = %Q{RENAME TABLE #{@table} TO #{@trash_table}}
    puts from_rename = %Q{RENAME TABLE #{@temp_table} TO #{@table}}
  end
  
  def cleanup
    puts cleanup = %Q{DROP TABLE #{@trash_table}}
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
    action = gets(:action).downcase
  end
  
  # raw: teaser_lock tinyint(1) DEFAULT '0'
  def parse_mod
    column = gets(:mod)
  end

end

