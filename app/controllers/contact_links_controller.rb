class ContactLinksController < ApplicationController
  def create
    other_user = User.find_by(email: params[:other_user_email].to_s.strip.downcase)
    unless other_user && other_user != current_user
      return redirect_to person_path(params[:person_id]),
        alert: "No other Serendipity user found with that email."
    end

    my_person = current_user.people.find(params[:person_id])
    their_person = other_user.people.find_by(email: my_person.email)
    unless their_person
      return redirect_to person_path(my_person),
        alert: "#{other_user.display_label} doesn't have #{my_person.name} (#{my_person.email}) in their contacts yet."
    end

    link = ContactLink.new(requester_person: my_person, recipient_person: their_person)
    if link.save
      redirect_to person_path(my_person),
        notice: "Invite sent to #{other_user.display_label}. They'll see it when they view #{my_person.name}."
    else
      redirect_to person_path(my_person), alert: link.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to people_path, alert: "Contact not found."
  end

  def update
    link = ContactLink.find(params[:id])
    return redirect_to people_path, alert: "Not authorized." unless link.recipient_person.user == current_user

    link.accepted!
    redirect_to person_path(link.recipient_person),
      notice: "Linked with #{link.requester_person.user.display_label}'s record. You'll now see shared history."
  end

  def destroy
    link = ContactLink.find(params[:id])
    parties = [ link.requester_person.user, link.recipient_person.user ]
    return redirect_to people_path, alert: "Not authorized." unless parties.include?(current_user)

    my_person = current_user == link.requester_person.user ? link.requester_person : link.recipient_person
    link.destroy
    redirect_to person_path(my_person), notice: "Contact link removed."
  rescue ActiveRecord::RecordNotFound
    redirect_to people_path, alert: "Link not found."
  end
end
