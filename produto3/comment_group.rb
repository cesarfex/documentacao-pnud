class CommentGroupPlugin::AllowComment < Noosfero::Plugin::Macro
  def self.configuration
    { :params => [],
      :skip_dialog => true,
      :generator => 'makeCommentable();',
      :js_files => 'comment_group.js',
      :icon_path => '/designs/.../16x16/.../emblem-system.png',
      :css_files => 'comment_group.css' }
  end

  def parse(params, inner_html, source)
    group_id = params[:group_id].to_i
    article = source
    count = article.group_comments.without_spam.in_group(group_id).count

    proc {
      render :partial => 'comment_group_plugin_profile/comment_group',
             :locals => {:group_id => group_id,
                         :article_id => article.id,
                         :inner_html => inner_html,
                         :count => count,
                         :profile_identifier => article.profile.identifier
             }
    }
  end
end
