module SchemaTransformer
  class Base
    def initialize(base = File.expand_path("..", __FILE__), options = {})
      @db, @log, @mail = ActiveWrapper.setup(
        :base => base,
        :env => ENV['RAILS_ENV'] || 'development',
        :log => "schema_transformer"
      )
      @db.establish_connection
      @conn = ActiveRecord::Base.connection
    
      @batch_size = options[:batch_size] || 10_000
    end
  
    def gather_info
      ask "What is the name of the table you want to alter?"
      @table = gets(:table)
      @temp_table = "#{@table}_st_temp"
      @trash_table = "#{@table}_st_trash"

      @model = define_model(@table)
      ask "What is the modification to the table?"
      ask "Examples: ADD COLUMN teaser_lock tinyint(1) DEFAULT '0'"
      ask "          ADD INDEX slide_id (slide_id)"
      @mod = gets(:mod)
      @sql = {}
    end
  
    def create
      sql_create = %{CREATE TABLE #{@temp_table} LIKE #{@table}}
      sql_mod = %{ALTER TABLE #{@temp_table} #{@mod}}
      @conn.execute(sql_create)
      @conn.execute(sql_mod)
      @temp_model = define_model(@temp_table)
      @model.reset_column_information
      @temp_model.reset_column_information
      # puts @temp_model
    end
  
    def sync
      start = res = @conn.execute("SELECT max(id) AS max_id FROM `#{@temp_table}`")
      start = res.fetch_row[0].to_i + 1 # nil case is okay: [nil][0].to_i => nil 
      find_in_batches("users", :start => start, :batch_size => @batch_size) do |batch|
        # puts "batch #{batch.inspect}"
        lower = batch.first
        upper = batch.last
      
        columns = insert_columns_sql
        sql = %Q{
          INSERT INTO #{@temp_table} (
            SELECT #{columns}
          	FROM #{@table} WHERE id >= #{lower} AND id <= #{upper}
          )
        }
        # puts sql
        @conn.execute(sql)
      end
    end
  
    def final_sync
      sync
      columns = subset_columns.collect{|x| "#{@temp_table}.#{x} = #{@table}.#{x}" }.join(", ")
      sql = %{
        UPDATE #{@temp_table} INNER JOIN #{@table}
          ON #{@temp_table}.id = #{@table}.id
          SET #{columns}
        WHERE #{@table}.updated_at >= '#{1.day.ago.strftime("%Y-%m-%d")}'
      }
      @conn.execute(sql)
      # puts sql
    end
  
    def switch
      final_sync
      to_trash  = %Q{RENAME TABLE #{@table} TO #{@trash_table}}
      from_temp = %Q{RENAME TABLE #{@temp_table} TO #{@table}}
      @conn.execute(to_trash)
      @conn.execute(from_temp)
    end
  
    def cleanup
      sql = %Q{DROP TABLE #{@trash_table}}
      @conn.execute(sql)
    end
  
    # the parameter is only for testing
    def gets(name = nil)
      STDIN.gets.strip
    end
  
    def subset_columns
      removed = @model.column_names - @temp_model.column_names
      subset  = @model.column_names - removed
    end
  
    def insert_columns_sql
      # existing subset
      subset = subset_columns
    
      # added
      added_s = @temp_model.column_names - @model.column_names
      added = @temp_model.columns.
                select{|c| added_s.include?(c.name) }.
                collect{|c| "#{extract_default(c)} AS #{c.name}" }
    
      # combine both
      columns = subset + added
      sql = columns.join(", ")
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
  
    def define_model(table)
      # Object.const_set(table.classify, Class.new(ActiveRecord::Base))
      Object.class_eval(<<-code)
        class #{table.classify} < ActiveRecord::Base
          set_table_name "#{table}"
        end
      code
      table.classify.constantize # returns the constant
    end

  private
    def ask(msg)
      puts msg
    end

    def extract_default(col)
      @conn.quote(col.default)
    end
  
  end
end