defmodule Portermills.SeparationTest do
  @moduledoc "Lists and wishlists must not reference each other's code."
  use ExUnit.Case, async: true

  @lib Path.expand("../../lib", __DIR__)

  defp sources(globs) do
    globs
    |> Enum.flat_map(&Path.wildcard(Path.join(@lib, &1)))
    |> Enum.map(&{&1, File.read!(&1)})
  end

  test "the lists context never mentions wishlists" do
    files =
      sources(["portermills/lists.ex", "portermills/lists/*.ex", "portermills_web/controllers/list_*.ex"])

    assert files != []

    for {path, source} <- files do
      # The moduledoc is allowed to say the contexts are separate.
      code = Regex.replace(~r/@moduledoc """.*?"""/s, source, "")
      refute code =~ ~r/wishlist/i, "#{path} references wishlists"
    end
  end

  test "the wishlists context never mentions the lists context" do
    files =
      sources([
        "portermills/wishlists.ex",
        "portermills/wishlists/*.ex",
        "portermills_web/controllers/wishlist_*.ex",
        "portermills_web/live/wishlist_live/*.ex"
      ])

    assert files != []

    for {path, source} <- files do
      code = Regex.replace(~r/@moduledoc """.*?"""/s, source, "")
      refute code =~ ~r/Portermills\.Lists|ListJSON|ListItem\b|Lists\./, "#{path} references lists"
    end
  end
end
