defmodule Portermills.Fixtures do
  @moduledoc "Test data builders."
  alias Portermills.{Accounts, Calendar, Lists, Wishlists}

  def family_fixture(name \\ "Family") do
    {:ok, family} = Accounts.create_family(%{name: "#{name} #{System.unique_integer([:positive])}"})
    family
  end

  def user_fixture(family, attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.create_user(family, Enum.into(attrs, %{name: "User #{n}", email: "user#{n}@example.com"}))

    user
  end

  def event_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Dentist",
        starts_at: ~U[2026-11-10 09:00:00Z],
        ends_at: ~U[2026-11-10 10:00:00Z]
      })

    {:ok, event} = Calendar.create_event(user.family_id, user.id, attrs)
    event
  end

  def list_fixture(family, attrs \\ %{}) do
    {:ok, list} = Lists.create_list(family.id, Enum.into(attrs, %{type: :shopping, name: "Shopping"}))
    list
  end

  def list_item_fixture(list, user, attrs \\ %{}) do
    {:ok, item} = Lists.add_item(list, user.id, Enum.into(attrs, %{name: "Milk"}))
    item
  end

  def template_fixture(family, attrs \\ %{}) do
    {:ok, template} =
      Lists.create_template(family.id, Enum.into(attrs, %{name: "Camping", items: ["Tent", "Stove"]}))

    template
  end

  def wishlist_fixture(user), do: Wishlists.get_or_create_wishlist(user)

  def wishlist_item_fixture(wishlist, attrs \\ %{}) do
    {:ok, item} = Wishlists.add_item(wishlist, Enum.into(attrs, %{name: "Book"}))
    item
  end
end
