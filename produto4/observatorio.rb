class Observatory
  belongs_to :person

  attr :categories_ids
  attr :tags_ids

  def itens
    Article.find(:all, :conditions => {
      :category_id => categories_ids,
      :tag_id => tags_ids
    })
  end
end

person = Person.find('username')
itens = person.observatory.itens

itens.each do |item|
  content_tag('div', item.icon +
              content_tag('span', item.date) +
              content_tag('span', item.title)
             )
end
