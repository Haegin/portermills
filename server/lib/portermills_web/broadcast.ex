defmodule PortermillsWeb.Broadcast do
  @moduledoc """
  Tells a family's other devices about a write made over REST.

  Topics are `family:<family_id>:calendar`, `family:<family_id>:lists` and
  `family:<family_id>:wishlists`, the ones `PortermillsWeb.FamilyChannel` serves.
  """

  def calendar(family_id, event, payload), do: send_to(family_id, "calendar", event, payload)
  def lists(family_id, event, payload), do: send_to(family_id, "lists", event, payload)
  def wishlists(family_id, event, payload), do: send_to(family_id, "wishlists", event, payload)

  def topic(family_id, feature), do: "family:#{family_id}:#{feature}"

  defp send_to(family_id, feature, event, payload) do
    PortermillsWeb.Endpoint.broadcast(topic(family_id, feature), event, payload)
  end
end
