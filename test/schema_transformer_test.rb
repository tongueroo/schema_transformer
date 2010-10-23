#!/usr/bin/env ruby

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'pp'
require File.expand_path("../../lib/schema_transformer", __FILE__)

# open to mock out methods
module SchemaTransformer
  class Base
    def ask(msg)
      nil
    end
    def gets(name = nil)
      case name
      when :table
        "users"
      when :mod
        "ADD COLUMN active tinyint(1) DEFAULT '0', 
         ADD COLUMN title varchar(255) DEFAULT 'Mr', 
         DROP COLUMN about_me"
      else
        raise "gets method: need to mock out #{name}"
      end
    end
  end
end

def setup_fixtures
  ActiveRecord::Base.connection.drop_table(:users_st_temp, :force => true) rescue nil
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
end

class SchemaTransformerTest < Test::Unit::TestCase
  def setup
    @transformer = SchemaTransformer::Base.new(File.expand_path("../fake_app", __FILE__))
    @conn = ActiveRecord::Base.connection
    setup_fixtures
  end

  # def test_find_in_batches
  #   i = 0
  #   bounds = [[8, 17], [18, 27], [28,35]]
  #   @transformer.find_in_batches("users", :start => 8, :batch_size => 10) do |batch|
  #     # puts "batch #{batch.inspect}"
  #     lower = batch.first
  #     upper = batch.last
  #     assert_equal bounds[i][0], lower
  #     assert_equal bounds[i][1], upper
  #     # puts("syncing over records #{lower} to #{upper}...")
  #     i += 1
  #   end
  # end
  # 
  # def test_base_sync
  #   @transformer.run
  #   @transformer.create_rename
  #   puts @transformer.base_sync
  # end
  # 
  # def test_final_sync
  #   @transformer.run
  #   @transformer.create_rename
  #   puts @transformer.final_sync
  # end

  def test_all
    @transformer.gather_info
    
    assert_equal ["users"], @conn.tables
    @transformer.create
    assert_equal ["users", "users_st_temp"], @conn.tables
    
    assert_equal 0, UsersStTemp.count
    @transformer.sync
    assert_equal User.count, UsersStTemp.count
    
    assert_equal ["users", "users_st_temp"], @conn.tables
    @transformer.switch
    assert_equal ["users", "users_st_trash"], @conn.tables
    
    @transformer.cleanup
    assert_equal ["users"], @conn.tables
  end
end
