#!/usr/bin/env ruby

require File.expand_path("../test_helper", __FILE__)

class SchemaTransformerTest < Test::Unit::TestCase
  def setup
    @base = File.expand_path("../fake_app", __FILE__)
    @transformer = SchemaTransformer::Transform.new(@base, :batch_size => 10, :stagger => 0)
    setup_fixtures
    setup_stubs
    
    @transform_file = @base+"/config/schema_transformations/users.json"
    File.delete(@transform_file) if File.exist?(@transform_file)
  end
  
  def test_books_no_updated_at_no_data
    @transformer = SchemaTransformer::Transform.new(@base, :batch_size => 10, :stagger => 0)
    @conn.execute("delete from books")
  
    @transformer.expects(:gets).with(:table).returns("books")
    @transformer.expects(:gets).with(:mod).returns("ADD COLUMN active tinyint(1) DEFAULT '0'")
    
    @transformer.generate
    @transformer.gather_info("books")
  
    assert_table_exist("books")
    assert_table_not_exist("books_st_temp")
    @transformer.create
    assert_table_exist("books_st_temp")
  
    @transformer.final_sync
  end
  
  def test_books_no_updated_at_with_data
    @transformer = SchemaTransformer::Transform.new(@base, :batch_size => 10, :stagger => 0)
    @transformer.expects(:gets).with(:table).returns("books")
    @transformer.expects(:gets).with(:mod).returns("ADD COLUMN active tinyint(1) DEFAULT '0'")
    
    @transformer.generate
    @transformer.gather_info("books")
  
    assert_table_exist("books")
    assert_table_not_exist("books_st_temp")
    @transformer.create
    assert_table_exist("books_st_temp")
  
    @transformer.final_sync
  end
  
  def test_find_in_batches
    i = 0
    bounds = [[8, 17], [18, 27], [28,35]]
    @transformer.find_in_batches("users", :start => 8, :batch_size => 10) do |batch|
      # puts "batch #{batch.inspect}"
      lower = batch.first
      upper = batch.last
      assert_equal bounds[i][0], lower
      assert_equal bounds[i][1], upper
      # puts("syncing over records #{lower} to #{upper}...")
      i += 1
    end
  end
  
  def test_run_sync_black_box
    @transformer.generate
    c1 = count("users")
    SchemaTransformer::Transform.run(:base => @base, :action => ["sync", "users"])
    c2 = count("users_st_temp")
    assert_equal c1, c2
  end
  
  def test_run_sync_black_box_repeatedly
    @transformer.generate
    c1 = count("users")
    # first run
    SchemaTransformer::Transform.run(:base => @base, :action => ["sync", "users"])
    assert_equal c1, count("users_st_temp")
    @conn.execute("delete from users_st_temp order by id desc limit 10")
    assert_equal c1, count("users_st_temp") + 10
    # second run
    SchemaTransformer::Transform.run(:base => @base, :action => ["sync", "users"])
    assert_equal c1, count("users_st_temp")
  end
  
  def test_run_switch_black_box
    @transformer.generate
    c1 = count("users")
    SchemaTransformer::Transform.run(:base => @base, :action => ["sync", "users"])
    c2 = count("users_st_temp")
    assert_equal c1, c2
    @conn.execute("delete from users_st_temp order by id desc limit 10")
    assert_equal c1, count("users_st_temp") + 10
  
    # This is what Im testing
    col1 = User.columns.size
    SchemaTransformer::Transform.run(:base => @base, :action => ["switch", "users"])
    User.reset_column_information
    assert_equal col1 + 1, User.columns.size
    assert_equal c1, count("users") # this is the new table
  end
  
  def test_run_tranformations_white_box
    @transformer.generate
    @transformer.gather_info("users")
    
    assert_table_exist("users")
    assert_table_not_exist("users_st_temp")
    @transformer.create
    assert_table_exist("users_st_temp")
    
    assert_equal 0, UsersStTemp.count
    @transformer.sync
    assert_equal User.count, UsersStTemp.count
    
    assert_table_exist("users")
    @transformer.switch
    assert_table_exist("users_st_trash")
    assert_table_not_exist("users_st_temp")
    
    @transformer.cleanup
    assert_table_exist("users")
    assert_table_not_exist("users_st_trash")
    assert_table_not_exist("users_st_temp")
  end
  
  def test_generate_transformations
    assert !File.exist?(@transform_file)
    @transformer.generate
    assert File.exist?(@transform_file)
    data = JSON.parse(IO.read(@transform_file))
    assert_equal "users", data["table"]
    assert_match /ADD COLUMN/, data["mod"]
    
    @transformer.gather_info("users")
    assert_equal "users", @transformer.instance_variable_get(:@table)
    assert_match /ADD COLUMN/, @transformer.instance_variable_get(:@mod)
  end
  
  def test_analyze_timestamps
    @analyze = SchemaTransformer::Analyze.new(@base)
    tables = @analyze.timestamps
    assert tables.include?("users") # has updated_at timestamp
    assert !tables.include?("books") # does not have updated_at timestamp
    tables = @analyze.no_timestamps
    assert !tables.include?("users") # has updated_at timestamp
    assert tables.include?("books") # does not have updated_at timestamp
  end

  def test_analyze_indexes
    @analyze = SchemaTransformer::Analyze.new(@base)
    tables = @analyze.indexes
    assert_equal [], tables
    tables = @analyze.no_indexes
    assert tables.include?("users") # has updated_at timestamp, but index
  end
end


