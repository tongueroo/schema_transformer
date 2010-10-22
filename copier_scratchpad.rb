#!/usr/bin/env ruby

ArticleRevision.find_in_batches

Activity

id, title, body, article_id, number, note, editor_id, created_at, blurb, teaser, source, slide_id, NULL test_id

def find_in_batches(options = {})
  raise "You can't specify an order, it's forced to be #{batch_order}" if options[:order]
  raise "You can't specify a limit, it's forced to be the batch_size"  if options[:limit]

  start = options.delete(:start).to_i
  batch_size = options.delete(:batch_size) || 1000

  with_scope(:find => options.merge(:order => batch_order, :limit => batch_size)) do
    records = find(:all, :conditions => [ "#{table_name}.#{primary_key} >= ?", start ])

    while records.any?
      yield records

      break if records.size < batch_size
      records = find(:all, :conditions => [ "#{table_name}.#{primary_key} > ?", records.last.id ])
    end
  end
end

res = conn.execute("SELECT max(`article_revisions_new`.id) AS max_id FROM `article_revisions_new`")
start = res.fetch_row[0].to_i # nil case is okay: [nil][0].to_i => nil 
Article::Revisions.find_in_batches(:start => start, :batch_size => 10_000) do |batch|
  lower = batch.first.id
  upper = batch.last.id
  execute(%{
    INSERT INTO article_revisions_new (
    	SELECT id, title, body, article_id, number, note, editor_id, created_at, blurb, teaser, source, slide_id 
    	FROM article_revisions WHERE id <= #{lower} AND id < #{upper}
    );
  })
end


pager = Pager.new(:per_page => 10_000, :lower => 300, :upper => 30_000)
pager.each do |page|
  puts page.start_index
end