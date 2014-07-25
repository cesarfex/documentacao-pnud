class PairwisePlugin::PairwiseContent < Article
  settings_items :pairwise_question_id
  settings_items :allow_new_ideas, :type => :boolean, :default => true

  REASONS_ARRAY = [
     {:text => _("I like both ideas"), :compare => false},
     {:text => _("I think both ideas are the same"), :compare => false},
     {:text => _("I don't know enough about either idea"), :compare => false},
     {:text => _("I don't like either idea"), :compare => false},
     {:text => _("I don't know enough about: "),:compare => true},
     {:text => _("I just can't decide"),:compare => false}
  ]

  def result_url
    profile.url.merge(
       :controller => :pairwise_plugin_profile,
       :action => :result,
       :id => id)
  end

  def prompt_url
    profile.url.merge(
       :controller => :pairwise_plugin_profile,
       :action => :prompt_tab,
       :id => id)
  end

  def self.short_description
    'Pairwise question'
  end

  def self.description
    'Question managed by pairwise'
  end

  def pairwise_client
    @pairwise_client ||=
      Pairwise::Client.build(profile.id,
                             environment.settings[:pairwise_plugin])
    @pairwise_client
  end

  def prepare_prompt(user_identifier, prompt_id=nil)
    prepared_question = question
    if has_next_prompt?
      prepared_question.set_prompt @next_prompt
    else
      prepared_question =
        self.question_with_prompt_for_visitor(user_identifier, prompt_id)
    end
    prepared_question
  end

  def question
    begin
      @question ||=
        pairwise_client.find_question_by_id(pairwise_question_id)
    rescue Exception => error
      errors.add_to_base(error.message)
    end
    @question
  end

  def pending_choices(filter, order)
    if(question)
      @inactive_choices ||= question.pending_choices(filter, order)
    else
      []
    end
  end

  def reproved_choices(filter, order)
    @reproved_choices ||=
      question ? question.reproved_choices(filter, order) : []
  end

  def inactive_choices(options={})
    if(question)
      @inactive_choices ||=
        (question.choices_include_inactive - question.get_choices)
    else
      []
    end
  end

  def raw_choices(filter=nil, order=nil)
    return [] if pairwise_question_id.nil?
    @raw_choices ||= question ? question.get_choices(filter, order) : []
  end

  def vote_to(prompt_id, direction, visitor, appearance_id)
    raise _("Excepted question not found") if question.nil?
    next_prompt =
      pairwise_client.vote(question.id, prompt_id, direction,
                           visitor, appearance_id)
    touch #invalidates cache
    set_next_prompt(next_prompt)
    next_prompt
  end

  def skip_prompt(prompt_id, visitor, appearance_id, reason=nil)
    next_prompt =
      pairwise_client.skip_prompt(question.id, prompt_id,
                                  visitor, appearance_id, reason)
    touch #invalidates cache
    set_next_prompt(next_prompt)
    next_prompt
  end

  def ask_skip_reasons(prompt)
    reasons = REASONS_ARRAY.map do |item|
      if item[:compare]
        [ item[:text] + prompt.left_choice_text,
          item[:text] + prompt.right_choice_text]
      else
        item[:text]
      end
    end
    reasons.flatten
  end

  def validate_choices
    errors.add_to_base(_("Choices empty")) if choices.nil?
    errors.add_to_base(_("Choices invalid format"))
      unless choices.is_a?(Array)
    errors.add_to_base(_("Choices invalid")) if choices.size == 0
    choices.each do | choice |
      if choice.empty?
        errors.add_to_base(_("Choice empty"))
        break
      end
    end
  end

  def update_choice(choice_id, choice_text, active)
    begin
      return pairwise_client.update_choice(question,
                                           choice_id, choice_text, active)
    rescue Exception => e
      errors.add_to_base(N_("Choices:") + " " + N_(e.message))
      return false
    end
  end

  def approve_choice(choice_id)
    begin
      return pairwise_client.approve_choice(question, choice_id)
    rescue Exception => e
      errors.add_to_base(N_("Choices:") + " " + N_(e.message))
      return false
    end
  end

  def find_choice id
    return nil if question.nil?
    question.find_choice id
  end

  def send_question_to_service
    if new_record?
      @question = create_pairwise_question
      self.pairwise_question_id = @question.id
      toggle_autoactivate_ideas(false)
    else
      unless @choices.nil?
        @choices.each do |choice_text|
          begin
            unless choice_text.empty?
              choice =
                pairwise_client.add_choice(pairwise_question_id,
                                           choice_text)
              pairwise_client.approve_choice(question, choice.id)
            end
          rescue Exception => e
            errors.add_to_base(
              N_("Choices: Error adding new choice to question") +
                N_(e.message)
            )
            return false
          end
        end
      end
      unless @choices_saved.nil?
        @choices_saved.each do |id,data|
          begin
            pairwise_client.update_choice(question, id, data, true)
          rescue Exception => e
            errors.add_to_base(N_("Choices:") + " " + N_(e.message))
            return false
          end
        end
      end
      begin
        pairwise_client.update_question(pairwise_question_id, name)
      rescue Exception => e
        errors.add_to_base(N_("Question not saved:  ") + N_(e.message))
        return false
      end
    end
  end
end
