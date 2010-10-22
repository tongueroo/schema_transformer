#!/usr/bin/env ruby

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
