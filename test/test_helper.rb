#!/usr/bin/env ruby

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'mocha'
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

  def count(table)
    res = @conn.execute("SELECT count(*) AS c FROM #{table}")
    c = res.fetch_row[0].to_i # nil case is okay: [nil][0].to_i => 0
  end
end

class Test::Unit::TestCase
  include TestExtensions
end
