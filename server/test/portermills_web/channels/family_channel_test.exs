defmodule PortermillsWeb.FamilyChannelTest do
  use PortermillsWeb.ChannelCase, async: true

  alias PortermillsWeb.{Broadcast, UserSocket}

  setup do
    family = family_fixture()
    %{family: family, user: user_fixture(family), other: user_fixture(family)}
  end

  defp connect_as(user) do
    {:ok, token, _claims} = Portermills.Guardian.encode_and_sign(user)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end

  test "the socket needs a valid token" do
    assert :error = connect(UserSocket, %{"token" => "nonsense"})
    assert :error = connect(UserSocket, %{})
  end

  test "a member can join their family's topics", %{user: user, family: family} do
    socket = connect_as(user)

    for feature <- ~w(calendar lists wishlists) do
      assert {:ok, _, _} = subscribe_and_join(socket, "family:#{family.id}:#{feature}")
    end
  end

  test "unknown topics and other families are refused", %{user: user, family: family} do
    socket = connect_as(user)
    other_family = family_fixture()

    assert {:error, %{reason: "unauthorized"}} = subscribe_and_join(socket, "family:#{other_family.id}:calendar")
    assert {:error, %{reason: "unauthorized"}} = subscribe_and_join(socket, "family:#{family.id}:secrets")
    assert {:error, %{reason: "unauthorized"}} = subscribe_and_join(socket, "family:#{family.id}")
  end

  test "REST broadcasts reach joined clients", %{user: user, family: family} do
    {:ok, _, _} = subscribe_and_join(connect_as(user), "family:#{family.id}:lists")
    Broadcast.lists(family.id, "list:item_added", %{item: %{id: "abc"}})
    assert_push "list:item_added", %{item: %{id: "abc"}}
  end

  test "clients can't write through the channel", %{user: user, family: family} do
    {:ok, _, socket} = subscribe_and_join(connect_as(user), "family:#{family.id}:lists")
    ref = push(socket, "list:add_item", %{"list_id" => Ecto.UUID.generate(), "name" => "x"})
    assert_reply ref, :error, %{reason: "unsupported"}
    refute_broadcast "list:item_added", _
  end

  describe "claims on a wishlist" do
    setup %{family: family, user: owner} do
      %{topic: "family:#{family.id}:wishlists", payload: %{wishlist_id: "w1", owner_id: owner.id}}
    end

    test "are not announced to its owner", %{user: owner, family: family, topic: topic, payload: payload} do
      {:ok, _, _} = subscribe_and_join(connect_as(owner), topic)

      Broadcast.wishlists(family.id, "wishlist:claims_changed", payload)
      refute_push "wishlist:claims_changed", _

      # Item changes do reach the owner.
      Broadcast.wishlists(family.id, "wishlist:updated", %{wishlist_id: "w1"})
      assert_push "wishlist:updated", %{wishlist_id: "w1"}
    end

    test "are announced to everyone else, without the owner id", %{other: other, family: family, topic: topic, payload: payload} do
      {:ok, _, _} = subscribe_and_join(connect_as(other), topic)

      Broadcast.wishlists(family.id, "wishlist:claims_changed", payload)
      assert_push "wishlist:claims_changed", pushed
      assert pushed == %{wishlist_id: "w1"}
    end
  end
end
