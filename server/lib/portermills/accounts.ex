defmodule Portermills.Accounts do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Accounts.{User, Family, MagicToken}

  def get_user(id), do: Repo.get(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc "Looks a user up by email address, ignoring case and surrounding whitespace."
  def find_user_by_email(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()

    Repo.one(from u in User, where: fragment("lower(?)", u.email) == ^normalized, limit: 1)
  end

  def create_magic_link(email) do
    with %User{} = user <- get_user_by_email(email) do
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      expires_at = DateTime.add(DateTime.utc_now(), 15 * 60, :second)
      %MagicToken{}
      |> MagicToken.changeset(%{token: token, expires_at: expires_at, user_id: user.id})
      |> Repo.insert()
    else
      nil -> {:error, :not_found}
    end
  end

  def verify_magic_token(token) do
    now = DateTime.utc_now()

    query =
      from t in MagicToken,
        where: t.token == ^token and t.expires_at > ^now and is_nil(t.used_at),
        preload: :user

    case Repo.one(query) do
      nil ->
        {:error, :invalid_token}

      %MagicToken{} = mt ->
        Repo.update!(MagicToken.changeset(mt, %{used_at: now}))
        {:ok, mt.user}
    end
  end

  def list_family_members(family_id) do
    Repo.all(from u in User, where: u.family_id == ^family_id)
  end
end
