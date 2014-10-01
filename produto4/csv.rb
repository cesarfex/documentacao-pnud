puts "id;title;status"

article = Article.find(...)

article.comments.each do |comment|
  print [comment.id, comment.title].join(";")
  comment.status.each do |status|
    print ";" + status
  end
  puts ""
end
