  categories = @environment.categories
  categories.map do |cat|
    link_to cat.name, :category, :id => cat.id
  end.map do |link|
    content_tag('li', link)
  end.join("\n")
