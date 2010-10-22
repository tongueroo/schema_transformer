#!/usr/bin/env ruby

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'pp'
require "schema_changer"

# open to mock out methods
class SchemaChanger
  def gets(name = nil)
    case name
    when :table
      "users"
    when :action
      "add_column"
    when :mod
      "ADD COLUMN teaser_lock tinyint(1) DEFAULT '0'"
    else
      raise "gets method: need to mock out #{name}"
    end
  end
end

def setup_fixtures
  ActiveRecord::Base.connection.drop_table(:users_schema_temp, :force => true) rescue nil
  ActiveRecord::Base.connection.create_table :users, :force => true do |table|
    table.column :name, :string
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

class SchemaChangerTest < Test::Unit::TestCase
  def setup
    @changer = SchemaChanger.new
    setup_fixtures
  end

  # def test_find_in_batches
  #   i = 0
  #   bounds = [[8, 17], [18, 27], [28,35]]
  #   @changer.find_in_batches("users", :start => 8, :batch_size => 10) do |batch|
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
  #   @changer.run
  #   @changer.create_rename
  #   puts @changer.base_sync
  # end
  # 
  # def test_final_sync
  #   @changer.run
  #   @changer.create_rename
  #   puts @changer.final_sync
  # end

  def test_all
    @changer.run
    @changer.create
    @changer.sync
    @changer.switch
    @changer.cleanup
  end
end
