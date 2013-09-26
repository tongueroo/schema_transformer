module SchemaTransformer
  class UsageError < RuntimeError; end
  
  class Transform < Base
    include Help
    @@stagger = 0
    def self.run(options)
      @@stagger = options[:stagger] ? options[:stagger].to_f : 0
      @transformer = SchemaTransformer::Transform.new(options[:base] || Dir.pwd)
      @transformer.run(options)
    end
    
    attr_reader :temp_table, :table
    def initialize(base = File.expand_path("..", __FILE__), options = {})
      super
      @batch_size = options[:batch_size] || 10_000
    end
    
    def run(options)
      @action = options[:action].first
      case @action
      when "generate"
        self.generate
        help(:generate)
      when "sync"
        help(:sync_progress)
        table = options[:action][1]
        self.gather_info(table)
        self.create
        self.sync
        help(:sync)
      when "switch"
        table = options[:action][1]
        self.gather_info(table)
        self.switch
        self.cleanup
        help(:switch)
      else
        raise UsageError, "Invalid action #{@action}"
      end
    end
    
    def generate
      data = {}
      ask "What is the name of the table you want to alter?"
      data[:table] = gets(:table)
      ask <<-TXT
What is the modification to the table?
Examples 1: 
  ADD COLUMN smart tinyint(1) DEFAULT '0'
Examples 2: 
  ADD INDEX idx_name (name)
Examples 3: 
  ADD COLUMN smart tinyint(1) DEFAULT '0', DROP COLUMN full_name
TXT
      data[:mod] = gets(:mod)
      path = transform_file(data[:table])
      FileUtils.mkdir(File.dirname(path)) unless File.exist?(File.dirname(path))
      File.open(path,"w") { |f| f << data.to_json }
      @table = data[:table]
      data
    end
    
    def gather_info(table)
      if table.nil?
        raise UsageError, "You need to specific the table name: schema_transformer #{@action} <table_name>"
      end
      data = JSON.parse(IO.read(transform_file(table)))
      @table = data["table"]
      @mod = data["mod"]
      # variables need for rest of the program
      @temp_table = "#{@table}_st_temp"
      @trash_table = "#{@table}_st_trash"
      @model = define_model(@table)
    end
  
    def create
      if self.temp_table_exists?
        @temp_model = define_model(@temp_table)
      else
        sql_create = %{CREATE TABLE #{@temp_table} LIKE #{@table}}
        sql_mod = %{ALTER TABLE #{@temp_table} #{@mod}}
        @conn.execute(sql_create)
        @conn.execute(sql_mod)
        @temp_model = define_model(@temp_table)
      end
      reset_column_info
    end
    
    def sync
      res = @conn.execute("SELECT max(id) AS max_id FROM `#{@temp_table}`")
      start = res.fetch_row[0].to_i + 1 # nil case is okay: [nil][0].to_i => 0
      find_in_batches(@table, :start => start, :batch_size => @batch_size) do |batch|
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
        
        if @@stagger > 0
          log("Staggering: delaying for #{@@stagger} seconds before next batch insert")
          sleep(@@stagger)
        end
      end
    end
  
    def final_sync
      @temp_model = define_model(@temp_table)
      reset_column_info
      
      sync
      columns = subset_columns.collect{|x| "#{@temp_table}.`#{x}` = #{@table}.`#{x}`" }.join(", ")
      # need to limit the final sync, if we do the entire table it takes a long time
      limit_cond = get_limit_cond
      sql = %{
        UPDATE #{@temp_table} INNER JOIN #{@table}
          ON #{@temp_table}.id = #{@table}.id
          SET #{columns}
        WHERE #{limit_cond}
      }
      # puts sql
      @conn.execute(sql)
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
    
    def get_limit_cond
      if @model.column_names.include?("updated_at")
        "#{@table}.updated_at >= '#{1.day.ago.strftime("%Y-%m-%d")}'"
      else
        res = @conn.execute("SELECT max(id) AS max_id FROM `#{@table}`")
        max = res.fetch_row[0].to_i + 1 # nil case is okay: [nil][0].to_i => 0
        bound = max - 100_000 < 0 ? 0 : max
        "#{@table}.id >= #{bound}"
      end
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
                collect{|c| "#{extract_default(c)} AS `#{c.name}`" }
    
      # combine both
      columns = subset.collect{|x| "`#{x}`"} + added
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

    def transform_file(table)
      @base+"/config/schema_transformations/#{table}.json"
    end
  
    def temp_table_exists?
      @conn.table_exists?(@temp_table)
    end
    
    def reset_column_info
      @model.reset_column_information
      @temp_model.reset_column_information
    end
    
    def log(msg)
      @log.info(msg)
    end
    
  private
    def ask(msg)
      puts msg
      print "> "
    end
    
    def extract_default(col)
      @conn.quote(col.default)
    end
  
  end
end
