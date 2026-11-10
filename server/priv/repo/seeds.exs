alias Portermills.Repo
alias Portermills.Accounts.{Family, User}

if Mix.env() == :dev do
  {:ok, family} =
    %Family{}
    |> Family.changeset(%{name: "Porter Mills"})
    |> Repo.insert(on_conflict: :nothing)

  if family.id do
    %User{}
    |> User.changeset(%{name: "Admin", email: "admin@portermills.app", role: :admin, family_id: family.id})
    |> Repo.insert(on_conflict: :nothing)
  end
end
