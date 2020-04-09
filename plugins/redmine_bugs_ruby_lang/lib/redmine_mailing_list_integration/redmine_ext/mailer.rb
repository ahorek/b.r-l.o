module MailingListIntegrationMailer

  def issue_add_mailing_list(user, issue)
    mailing_lists = issue.project.mail_routes_for_issue(issue)
    record_message(issue, nil, mailing_lists)
    m = issue_add(user, issue)

    m.header[:to] = mailing_lists.map(&:address)
    m
  end

  def issue_edit_mailing_list(user, journal)
    issue = journal.issue
    mailing_lists = issue.project.mail_routes_for_issue(issue)
    record_message(issue, journal, mailing_lists)
    m = issue_edit(user, journal)

    m.header[:to] = mailing_lists.map(&:address)
    m
  end

  def attachments_added(user, attachments)
    mailing_lists = attatchments.first.container.project.mail_routes_for_attachments(attachments)

    m = super(user, attachments)

    m.header[:to] = mailing_lists.map(&:address)
    m
  end

  private

  def record_message(issue, journal, mailing_lists)
    message_record_ids = mailing_lists.map {|ml|
      record = MailingListMessage.create!(
        mailing_list: ml,
        issue: issue,
        journal: journal
      )
      record.id
    }
    headers['X-Redmine-MailingListIntegration-Message-Ids'] = message_record_ids.join(",")
  end
end

module MailingListIntegrationMailerClass
  def deliver_issue_add(issue)
    unless issue.originates_from_mail?
      super
      issue_add_mailing_list(issue.author, issue).deliver_later
    end
  end

  def deliver_issue_edit(journal)
    unless journal.originates_from_mail?
      super
      issue_edit_mailing_list(journal.issue.author, journal).deliver_later
    end
  end

  def deliver_attachments_added(attachments)
    attachment = attachments.first
    return unless attachment.container_type == 'Issue'
    attachments_added(attachment.container.author, attachments).deliver_later
  end
end

Mailer.class_eval do
  prepend MailingListIntegrationMailer
  singleton_class.prepend MailingListIntegrationMailerClass
end
