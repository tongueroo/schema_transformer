module SchemaTransformer
  class Base
    attr_reader :options
    def initialize(base = File.expand_path("..", __FILE__), options = {})
      @base = base
      @db, @log, @mail = ActiveWrapper.setup(
        :base => @base,
        :env => ENV['RAILS_ENV'] || 'development',
        :log => "schema_transformer"
      )
      @db.establish_connection
      @conn = ActiveRecord::Base.connection
    end
  end
end
