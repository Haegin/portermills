# Development data: one family with two members (so claiming on each other's
# wishlists can be tried), a shopping list, and a few packing-list templates.
# Safe to run more than once.
alias Portermills.{Accounts, Lists, Repo}
alias Portermills.Accounts.Family

if Mix.env() == :dev do
  family =
    case Repo.get_by(Family, name: "Porter-Mills") do
      nil ->
        {:ok, family} = Accounts.create_family(%{name: "Porter-Mills"})
        family

      family ->
        family
    end

  for {name, email, role} <- [
        {"Admin", "admin@portermills.app", :admin},
        {"Sam", "sam@portermills.app", :member}
      ],
      is_nil(Accounts.get_user_by_email(email)) do
    {:ok, _} = Accounts.create_user(family, %{name: name, email: email, role: role})
  end

  if Lists.list_lists(family.id) == [] do
    {:ok, _} = Lists.create_list(family.id, %{type: :shopping, name: "Shopping"})
  end

  if Lists.list_templates(family.id) == [] do
    for {name, items} <- [
          {"Beach holiday", ~w(Passports Swimwear Suncream Sunglasses Towels Flip-flops Chargers)},
          {"Camping", ["Tent", "Sleeping bags", "Stove", "Head torches", "Waterproofs", "First aid kit"]},
          {"Weekend away", ["Toothbrushes", "Pyjamas", "Chargers", "Change of clothes"]}
        ] do
      {:ok, _} = Lists.create_template(family.id, %{name: name, items: items})
    end
  end
end
