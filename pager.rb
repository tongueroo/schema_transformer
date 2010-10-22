# Most of this is ripped off from WillPaginate::Collection
#
# Required options:
# * <tt>per_page</tt> - number of items per page
# Optional options:
# * <tt>page</tt> - starting page, defaults to 1
# * <tt>total</tt> - total number of items, defaults to 0
#  
# Usage:
# 
#   pager = Pager.new(:per_page => 5, :total => 23)
#   pager.start_index => 0
#   pager.end_index => 4
#
#   pager = Pager.new(:page => 2, :per_page => 5, :total => 23)
#   pager.start_index => 5
#   pager.end_index => 9
#
#   # interator will always loop starting from page 1, even if you have initialize page another value.
#   pager.each do |page|
#     page.start_index
#     page.end_index
#   end
class Pager
  include Enumerable
  
  def each
    old = @current_page # want to remember the old current page
    @current_page = 1
    @total_pages.times do
      yield(self)
      @current_page += 1
     end
     @current_page = old
  end
  
  attr_reader :current_page, :per_page, :total_pages
  attr_accessor :total_entries

  def initialize(options)
    @current_page  = options[:page] ? options[:page].to_i : 1
    @per_page      = options[:per_page].to_i
    @total_entries = options[:total].to_i
    @total_pages   = (@total_entries / @per_page.to_f).ceil
  end

  # The total number of pages.
  def page_count
    @total_pages
  end

  # Current offset of the paginated collection. If we're on the first page,
  # it is always 0. If we're on the 2nd page and there are 30 entries per page,
  # the offset is 30. This property is useful if you want to render ordinals
  # besides your records: simply start with offset + 1.
  #
  def offset
    (current_page - 1) * per_page
  end

  # current_page - 1 or nil if there is no previous page
  def previous_page
    current_page > 1 ? (current_page - 1) : nil
  end
  
  def previous_page!
    @current_page = previous_page if previous_page
  end

  # current_page + 1 or nil if there is no next page
  def next_page
    current_page < page_count ? (current_page + 1) : nil
  end
  
  def next_page!
    @current_page = next_page if next_page
  end
  
  def start_index
    offset
  end
  
  def end_index
    [start_index + (per_page - 1), @total_entries].min
  end
  
  # true if current_page is the final page
  def last_page?
    next_page.nil?
  end
  
  # true if current_page is the final page
  def first_page?
    previous_page.nil?
  end
  
  # true if current_page is the final page
  def first_page!
    @current_page = 1
  end
end
