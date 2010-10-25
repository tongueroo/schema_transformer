module SchemaTransformer
  class Analyze < Base
    def self.run(options)
      @analyze = Analyze.new(options[:base] || Dir.pwd, options)
      puts "Analyzing your database schema..."
      if @analyze.no_timestamps.empty?
        puts "There are no tables without the updated_at timestamp.  GOOD"
      else
        puts "These tables do not have updated_at timestamps: "
        puts "  #{@analyze.no_timestamps.join("\n  ")}"
      end
      if @analyze.no_indexes.empty?
        puts "There are no tables with updated_at timestamp but no indexes.  GOOD"
      else
        puts "These tables do have an updated_at timestamp, but no index: "
        puts "  #{@analyze.no_indexes.join("\n  ")}"
      end
      if @analyze.no_timestamps.empty? or @analyze.no_timestamps.empty?
        "Everything looks GOOD!"
      else
        puts "You should add the missing columns or indexes."
      end
    end
    
    # tells which tables are missing updated_at and index on updated_at
    def no_timestamps
      @conn.tables - timestamps
    end
    
    def timestamps
      tables = []
      @conn.tables.each do |table|
        has_updated_at = @conn.columns(table).detect {|col| col.name == "updated_at" }
        tables << table if has_updated_at
      end
      tables
    end
    
    def indexes
      tables = []
      timestamps.each do |table|
        has_index = @conn.indexes(table).detect {|col| col.columns == ["updated_at"] }
        tables << table if has_index
      end
      tables
    end
    
    def no_indexes
      timestamps - indexes
    end
  end
end