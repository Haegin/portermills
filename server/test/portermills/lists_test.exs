defmodule Portermills.ListsTest do
  use Portermills.DataCase, async: true

  alias Portermills.Lists

  setup do
    family = family_fixture()
    %{family: family, user: user_fixture(family)}
  end

  describe "lists" do
    test "create, rename, archive and delete", %{family: family} do
      assert {:ok, list} = Lists.create_list(family.id, %{"type" => "packing", "name" => "Skiing"})
      assert list.type == :packing

      assert {:ok, list} = Lists.update_list(list, %{name: "Ski trip"})
      assert [%{name: "Ski trip"}] = Lists.list_lists(family.id)

      assert {:ok, list} = Lists.update_list(list, %{archived: true})
      assert Lists.list_lists(family.id) == []

      assert {:ok, _} = Lists.delete_list(list)
      assert Lists.get_list(family.id, list.id) == nil
    end

    test "a list needs a valid type and a name", %{family: family} do
      assert {:error, changeset} = Lists.create_list(family.id, %{type: "todo"})
      assert %{type: ["is invalid"], name: ["can't be blank"]} = errors_on(changeset)
    end

    test "the type can't be changed after creation", %{family: family} do
      list = list_fixture(family)
      {:ok, list} = Lists.update_list(list, %{type: :packing, name: "Still shopping"})
      assert list.type == :shopping
    end

    test "lists carry item counts", %{family: family, user: user} do
      list = list_fixture(family)
      milk = list_item_fixture(list, user)
      list_item_fixture(list, user, %{name: "Eggs"})
      {:ok, _} = Lists.update_item(milk, %{checked: true})

      assert [%{item_count: 2, checked_count: 1}] = Lists.list_lists(family.id)
      assert %{item_count: 2, checked_count: 1} = Lists.get_list(family.id, list.id)
    end

    test "lists are invisible to other families", %{family: family} do
      list = list_fixture(family)
      other = family_fixture()

      assert Lists.list_lists(other.id) == []
      assert Lists.get_list(other.id, list.id) == nil
      assert Lists.get_list(family.id, "garbage") == nil
    end
  end

  describe "items" do
    test "are appended in order", %{family: family, user: user} do
      list = list_fixture(family)
      {:ok, a} = Lists.add_item(list, user.id, %{"name" => "Milk"})
      {:ok, b} = Lists.add_item(list, user.id, %{"name" => "Eggs"})

      assert a.added_by_id == user.id
      assert {a.position, b.position} == {1, 2}
      assert Enum.map(Lists.list_items(list), & &1.name) == ["Milk", "Eggs"]
    end

    test "can be ticked, renamed and deleted", %{family: family, user: user} do
      list = list_fixture(family)
      item = list_item_fixture(list, user)

      assert {:ok, %{checked: true}} = Lists.update_item(item, %{"checked" => true})
      assert {:ok, %{name: "Oat milk"}} = Lists.update_item(item, %{"name" => "Oat milk"})
      assert {:ok, _} = Lists.delete_item(item)
      assert Lists.list_items(list) == []
    end

    test "get_item/2 only finds items of that list", %{family: family, user: user} do
      list = list_fixture(family)
      other_list = list_fixture(family, %{name: "Other"})
      item = list_item_fixture(list, user)

      assert Lists.get_item(list, item.id).id == item.id
      assert Lists.get_item(other_list, item.id) == nil
    end

    test "deleting a list deletes its items", %{family: family, user: user} do
      list = list_fixture(family)
      item = list_item_fixture(list, user)
      {:ok, _} = Lists.delete_list(list)
      refute Repo.get(Lists.ListItem, item.id)
    end
  end

  describe "templates" do
    test "keep their items in order", %{family: family} do
      {:ok, template} = Lists.create_template(family.id, %{"name" => "Beach", "items" => ["Towels", "Suncream"]})
      assert Enum.map(template.items, &{&1.name, &1.position}) == [{"Towels", 1}, {"Suncream", 2}]
      assert [listed] = Lists.list_templates(family.id)
      assert Enum.map(listed.items, & &1.name) == ["Towels", "Suncream"]
    end

    test "updating replaces the items", %{family: family} do
      template = template_fixture(family)
      {:ok, _} = Lists.update_template(template, %{"name" => "Wild camping", "items" => ["Tarp"]})

      reloaded = Lists.get_template(family.id, template.id)
      assert reloaded.name == "Wild camping"
      assert Enum.map(reloaded.items, & &1.name) == ["Tarp"]
    end

    test "a packing list created from a template gets a copy of its items", %{family: family, user: user} do
      template = template_fixture(family)

      assert {:ok, list} = Lists.create_list_from_template(template, user.id, %{"name" => "Lakes 2027"})
      assert %{type: :packing, name: "Lakes 2027", item_count: 2} = list
      assert [%{name: "Tent", checked: false}, %{name: "Stove"}] = Lists.list_items(list)

      # The copy is independent of the template.
      {:ok, _} = Lists.delete_template(template)
      assert length(Lists.list_items(list)) == 2
    end

    test "the list takes the template's name by default", %{family: family, user: user} do
      {:ok, list} = Lists.create_list_from_template(template_fixture(family), user.id)
      assert list.name == "Camping"
    end

    test "a list can be saved as a template", %{family: family, user: user} do
      list = list_fixture(family, %{type: :packing, name: "Festival"})
      list_item_fixture(list, user, %{name: "Wellies"})
      list_item_fixture(list, user, %{name: "Earplugs"})

      assert {:ok, template} = Lists.create_template_from_list(list)
      assert template.name == "Festival"
      assert Enum.map(template.items, & &1.name) == ["Wellies", "Earplugs"]
    end

    test "templates are invisible to other families", %{family: family} do
      template = template_fixture(family)
      other = family_fixture()

      assert Lists.list_templates(other.id) == []
      assert Lists.get_template(other.id, template.id) == nil
    end
  end
end
