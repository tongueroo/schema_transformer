#!/usr/bin/env ruby

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'mocha'
require 'pp'
require File.expand_path("../../lib/schema_transformer", __FILE__)

module TestExtensions
  def setup_fixtures
    @conn = ActiveRecord::Base.connection # shortcut to connection
    
    # cleanup in case tests fail half way
    @conn.drop_table(:users_st_temp, :force => true) rescue nil
    @conn.drop_table(:users_st_trash, :force => true) rescue nil
    
    @conn.create_table :users, :force => true do |table|
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

    # cleanup in case tests fail half way
    @conn.drop_table(:books_st_temp, :force => true) rescue nil
    @conn.drop_table(:books_st_trash, :force => true) rescue nil
    # no timestamp
    @conn.create_table :books, :force => true do |table|
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
  
  def setup_stubs
    SchemaTransformer::Base.any_instance.stubs(:gets).with(:table).returns("users")
    SchemaTransformer::Base.any_instance.stubs(:gets).with(:mod).returns(
      "ADD COLUMN active tinyint(1) DEFAULT '0', 
       ADD COLUMN title varchar(255) DEFAULT 'Mr', 
       DROP COLUMN about_me"
    )
    SchemaTransformer::Base.any_instance.stubs(:ask).returns(nil)
    SchemaTransformer::Base.any_instance.stubs(:help).returns(nil)
  end

  def count(table)
    res = @conn.execute("SELECT count(*) AS c FROM #{table}")
    c = res.fetch_row[0].to_i # nil case is okay: [nil][0].to_i => 0
  end
  
  def assert_table_exist(table)
    assert @conn.tables.include?(table)
  end

  def assert_table_not_exist(table)
    assert !@conn.tables.include?(table)
  end
end

class Test::Unit::TestCase
  include TestExtensions
end
