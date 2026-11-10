defmodule Portermills.Accounts.UserNotifier do
  import Swoosh.Email
  alias Portermills.Mailer

  def deliver_magic_link(user, url) do
    email =
      new()
      |> to({user.name, user.email})
      |> from(Application.fetch_env!(:portermills, :mail_from))
      |> subject("Your Porter-Mills sign-in link")
      |> text_body("""
      Hi #{user.name},

      Open this link on your phone to sign in to Porter-Mills:

      #{url}

      It works once and expires in 15 minutes. If you didn't ask for it, ignore this email.
      """)

    Mailer.deliver(email)
  end
end
