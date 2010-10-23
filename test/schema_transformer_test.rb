#!/usr/bin/env ruby

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'pp'
require File.expand_path("../../lib/schema_transformer", __FILE__)

# open to mock out methods
$testing_books = false # im being lazy, should use mocks
module SchemaTransformer
  class Base
    def ask(msg)
      nil
    end
    def gets(name = nil)
      case name
      when :table
        if $testing_books
          out = "books"
        else
          out = "users"
        end
      when :mod
        if $testing_books
          out = "ADD COLUMN active tinyint(1) DEFAULT '0'"
        else
          out = "ADD COLUMN active tinyint(1) DEFAULT '0', 
           ADD COLUMN title varchar(255) DEFAULT 'Mr', 
           DROP COLUMN about_me"
        end
      else
        raise "gets method: need to mock out #{name}"
      end
      out
    end
    def help(msg)
      nil
    end
  end
end

def setup_fixtures
  ActiveRecord::Base.connection.drop_table(:users_st_temp, :force => true) rescue nil
  ActiveRecord::Base.connection.drop_table(:users_st_trash, :force => true) rescue nil
  ActiveRecord::Base.connection.create_table :users, :force => true do |table|
    table.column :name, :string
    table.column :about_me, :string
    table.column :updated_at, :datetime
    table.column :created_at, :datetime
  end
  Object.send(:remove_const, "User") rescue nil
  Object.const_set("User", Class.new(ActiveRecord::Base))
  35.times do |i|
    User.create(:name => "name_#{i}")
  end
  Object.send(:remove_const, "User") rescue nil

  ActiveRecord::Base.connection.drop_table(:books_st_temp, :force => true) rescue nil
  ActiveRecord::Base.connection.drop_table(:books_st_trash, :force => true) rescue nil
  # no timestamp
  ActiveRecord::Base.connection.create_table :books, :force => true do |table|
    table.column :title, :string
    table.column :author, :string
  end
  Object.send(:remove_const, "Book") rescue nil
  Object.const_set("Book", Class.new(ActiveRecord::Base))
  4.times do |i|
    Book.create(:title => "title_#{i}")
  end
  Object.send(:remove_const, "Book") rescue nil
end

class SchemaTransformerTest < Test::Unit::TestCase
  def count(table)
    @conn = ActiveRecord::Base.connection
    res = @conn.execute("SELECT count(*) AS c FROM #{table}")
    c = res.fetch_row[0].to_i # nil case is okay: [nil][0].to_i => 0
  end
  
  def setup
    @base = File.expand_path("../fake_app", __FILE__)
    @transform_file = @base+"/config/schema_transformations/users.json"
    File.delete(@transform_file) if File.exist?(@transform_file)
    @transformer = SchemaTransformer::Base.new(@base, :batch_size => 10, :stagger => 0)
    @conn = ActiveRecord::Base.connection
    setup_fixtures
  end
  
  def test_no_updated_at_no_data
    @conn.execute("delete from books")
    $testing_books = true
    @transformer.generate
    @transformer.gather_info("books")
  
    assert @conn.tables.include?("books")
    assert !@conn.tables.include?("books_st_temp")
    @transformer.create
    assert @conn.tables.include?("books_st_temp")

    @transformer.final_sync
    $testing_books = false
  end

  def test_no_updated_at_with_data
    $testing_books = true
    @transformer.generate
    @transformer.gather_info("books")
  
    assert @conn.tables.include?("books")
    assert !@conn.tables.include?("books_st_temp")
    @transformer.create
    assert @conn.tables.include?("books_st_temp")

    @transformer.final_sync
    $testing_books = false
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
    SchemaTransformer::Base.run(:base => @base, :action => ["sync", "users"])
    c2 = count("users_st_temp")
    assert_equal c1, c2
  end
  
  def test_run_sync_black_box_repeatedly
    @transformer.generate
    c1 = count("users")
    # first run
    SchemaTransformer::Base.run(:base => @base, :action => ["sync", "users"])
    assert_equal c1, count("users_st_temp")
    @conn.execute("delete from users_st_temp order by id desc limit 10")
    assert_equal c1, count("users_st_temp") + 10
    # second run
    SchemaTransformer::Base.run(:base => @base, :action => ["sync", "users"])
    assert_equal c1, count("users_st_temp")
  end
  
  def test_run_switch_black_box
    @transformer.generate
    c1 = count("users")
    SchemaTransformer::Base.run(:base => @base, :action => ["sync", "users"])
    c2 = count("users_st_temp")
    assert_equal c1, c2
    @conn.execute("delete from users_st_temp order by id desc limit 10")
    assert_equal c1, count("users_st_temp") + 10
  
    # This is what Im testing
    col1 = User.columns.size
    SchemaTransformer::Base.run(:base => @base, :action => ["switch", "users"])
    User.reset_column_information
    assert_equal col1 + 1, User.columns.size
    assert_equal c1, count("users") # this is the new table
  end
  
  def test_run_tranformations_white_box
    @transformer.generate
    @transformer.gather_info("users")
    
    assert @conn.tables.include?("users")
    assert !@conn.tables.include?("users_st_temp")
    @transformer.create
    assert @conn.tables.include?("users_st_temp")
    
    assert_equal 0, UsersStTemp.count
    @transformer.sync
    assert_equal User.count, UsersStTemp.count
    
    assert @conn.tables.include?("users")
    @transformer.switch
    assert @conn.tables.include?("users_st_trash")
    assert !@conn.tables.include?("users_st_temp")
    
    @transformer.cleanup
    assert @conn.tables.include?("users")
    assert !@conn.tables.include?("users_st_trash")
    assert !@conn.tables.include?("users_st_temp")
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
end


