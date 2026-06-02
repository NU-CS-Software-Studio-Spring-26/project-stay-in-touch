class PersonFactsController < ApplicationController
  before_action :set_person

  def create
    fact = @person.person_facts.build(fact_params)
    if fact.save
      redirect_to person_path(@person), notice: "Fact added."
    else
      redirect_to person_path(@person), alert: fact.errors.full_messages.to_sentence
    end
  end

  def destroy
    @person.person_facts.find(params[:id]).destroy
    redirect_to person_path(@person), notice: "Fact removed."
  end

  def extract
    unless ENV["OPENROUTER_API_KEY"].present?
      redirect_to person_path(@person), alert: "AI is not configured."
      return
    end

    facts = PersonFactExtractionService.new(@person).call
    if facts.empty?
      redirect_to person_path(@person), alert: "No facts could be extracted from the notes."
      return
    end

    created = facts.count { |f| @person.person_facts.create(f.merge(noted_at: Date.current)) }
    redirect_to person_path(@person), notice: "#{created} fact#{"s" if created != 1} extracted from your notes."
  end

  private

  def set_person
    @person = current_user.people.find(params[:person_id])
  end

  def fact_params
    params.require(:person_fact).permit(:category, :body, :noted_at)
  end
end
