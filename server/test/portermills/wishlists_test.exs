defmodule Portermills.WishlistsTest do
  use Portermills.DataCase, async: true

  alias Portermills.Wishlists
  alias Portermills.Wishlists.Claim

  setup do
    family = family_fixture()
    owner = user_fixture(family, %{name: "Alex"})
    giver = user_fixture(family, %{name: "Sam"})
    %{family: family, owner: owner, giver: giver, wishlist: wishlist_fixture(owner)}
  end

  test "every family member gets one wishlist", %{owner: owner, giver: giver} do
    assert [a, b] = Wishlists.list_family_wishlists(owner)
    assert Enum.map([a, b], & &1.user.name) == ["Alex", "Sam"]
    assert b.user_id == giver.id

    # Listing again doesn't create more.
    assert length(Wishlists.list_family_wishlists(giver)) == 2
    assert Wishlists.get_or_create_wishlist(owner).id == a.id
  end

  test "wishlists carry an item count", %{owner: owner, wishlist: wishlist} do
    wishlist_item_fixture(wishlist)
    wishlist_item_fixture(wishlist)
    assert Wishlists.get_wishlist(owner, wishlist.id).item_count == 2
  end

  test "a hidden wishlist is only visible to its owner", %{owner: owner, giver: giver, wishlist: wishlist} do
    {:ok, _} = Wishlists.update_wishlist(wishlist, %{is_visible_to_family: false})

    assert Wishlists.get_wishlist(owner, wishlist.id)
    assert Wishlists.get_wishlist(giver, wishlist.id) == nil
    refute wishlist.id in Enum.map(Wishlists.list_family_wishlists(giver), & &1.id)
  end

  test "wishlists are invisible to other families", %{wishlist: wishlist} do
    stranger = user_fixture(family_fixture())
    item = wishlist_item_fixture(wishlist)

    assert Wishlists.get_wishlist(stranger, wishlist.id) == nil
    assert Wishlists.get_item_with_wishlist(stranger, item.id) == nil
    refute wishlist.id in Enum.map(Wishlists.list_family_wishlists(stranger), & &1.id)
  end

  test "items are ordered by priority and can be edited and deleted", %{owner: owner, wishlist: wishlist} do
    {:ok, low} = Wishlists.add_item(wishlist, %{"name" => "Socks", "priority" => "low"})
    {:ok, high} = Wishlists.add_item(wishlist, %{"name" => "Bike", "priority" => "high", "price" => "349.99"})

    assert Enum.map(Wishlists.list_items(wishlist, owner), & &1.name) == ["Bike", "Socks"]
    assert Decimal.equal?(high.price, Decimal.new("349.99"))

    assert {:ok, %{name: "Warm socks"}} = Wishlists.update_item(low, %{name: "Warm socks"})
    assert {:ok, _} = Wishlists.delete_item(high)
    assert [%{name: "Warm socks"}] = Wishlists.list_items(wishlist, owner)
  end

  describe "claims" do
    setup %{wishlist: wishlist} do
      %{item: wishlist_item_fixture(wishlist)}
    end

    test "another family member can claim and release an item", ctx do
      assert {:ok, claimed} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.giver)
      assert claimed.claim.claimed_by_id == ctx.giver.id

      assert {:ok, released} = Wishlists.unclaim_item(ctx.wishlist, ctx.item, ctx.giver)
      assert released.claim == nil
    end

    test "an item can only be claimed once", ctx do
      third = user_fixture(ctx.family)
      {:ok, _} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.giver)

      assert {:error, :already_claimed} = Wishlists.claim_item(ctx.wishlist, ctx.item, third)
      assert {:error, :already_claimed} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.giver)
    end

    test "nobody can release someone else's claim", ctx do
      third = user_fixture(ctx.family)
      {:ok, _} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.giver)

      assert {:ok, item} = Wishlists.unclaim_item(ctx.wishlist, ctx.item, third)
      assert item.claim.claimed_by_id == ctx.giver.id
    end

    test "the owner can't claim or release on their own wishlist", ctx do
      assert {:error, :forbidden} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.owner)
      assert {:error, :forbidden} = Wishlists.unclaim_item(ctx.wishlist, ctx.item, ctx.owner)
      assert Repo.aggregate(Claim, :count) == 0
    end

    test "the owner never gets claim data; others do", ctx do
      {:ok, _} = Wishlists.claim_item(ctx.wishlist, ctx.item, ctx.giver)

      assert [%{claim: %Ecto.Association.NotLoaded{}}] = Wishlists.list_items(ctx.wishlist, ctx.owner)
      assert %{claim: %Ecto.Association.NotLoaded{}} = Wishlists.get_item(ctx.wishlist, ctx.item.id, ctx.owner)

      assert [%{claim: %Claim{} = claim}] = Wishlists.list_items(ctx.wishlist, ctx.giver)
      assert claim.claimed_by.name == "Sam"
    end
  end

  describe "public sharing" do
    test "a share token is created once and can be revoked", %{wishlist: wishlist} do
      shared = Wishlists.ensure_share_token(wishlist)
      assert is_binary(shared.share_token)
      assert Wishlists.ensure_share_token(shared).share_token == shared.share_token
      assert Wishlists.get_wishlist_by_share_token(shared.share_token).id == wishlist.id

      Wishlists.revoke_share_token(shared)
      assert Wishlists.get_wishlist_by_share_token(shared.share_token) == nil
    end

    test "blank tokens match nothing", %{wishlist: _wishlist} do
      assert Wishlists.get_wishlist_by_share_token("") == nil
      assert Wishlists.get_wishlist_by_share_token(nil) == nil
    end
  end
end
