defmodule Portermills.Accounts do
  import Ecto.Query
  require Logger

  alias Portermills.Repo
  alias Portermills.Accounts.{User, Family, MagicToken, UserNotifier}

  @magic_link_ttl_seconds 15 * 60

  def get_user(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(User, id)
      :error -> nil
    end
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: normalize_email(email))
  end

  def get_user_by_email(_), do: nil

  def create_family(attrs) do
    %Family{} |> Family.changeset(attrs) |> Repo.insert()
  end

  def create_user(%Family{id: family_id}, attrs) do
    %User{family_id: family_id} |> User.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Adds a family member (there is no sign-up). The user joins the family named
  `family_name`, creating it if needed, or the only family when `family_name`
  is nil. Used by `mix portermills.add_user` and `bin/add_user` in releases.
  """
  def add_family_member(name, email, role, family_name \\ nil) do
    with {:ok, family} <- find_or_create_family(family_name),
         {:ok, user} <- create_user(family, %{name: name, email: email, role: role}) do
      {:ok, user, family}
    end
  end

  defp find_or_create_family(nil) do
    case Repo.all(Family) do
      [family] -> {:ok, family}
      [] -> {:error, "no family exists yet; pass a family name to create one"}
      _ -> {:error, "more than one family exists; pass a family name"}
    end
  end

  defp find_or_create_family(name) do
    case Repo.get_by(Family, name: name) do
      nil -> create_family(%{name: name})
      family -> {:ok, family}
    end
  end

  def list_family_members(family_id) do
    Repo.all(from u in User, where: u.family_id == ^family_id, order_by: u.name)
  end

  @doc """
  Creates a single-use token for the user with this email and returns the raw
  token. Only a hash of it is stored.
  """
  def create_magic_token(email) do
    case get_user_by_email(email) do
      nil ->
        {:error, :not_found}

      %User{} = user ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

        expires_at =
          DateTime.utc_now() |> DateTime.add(@magic_link_ttl_seconds) |> DateTime.truncate(:second)

        %MagicToken{user_id: user.id}
        |> MagicToken.changeset(%{token: hash_token(token), expires_at: expires_at})
        |> Repo.insert!()

        {:ok, user, token}
    end
  end

  @doc """
  Emails a magic link to the user with this email, if there is one.
  `url_fun` turns the raw token into the link that goes in the email.
  """
  def deliver_magic_link(email, url_fun) when is_function(url_fun, 1) do
    with {:ok, user, token} <- create_magic_token(email) do
      url = url_fun.(token)

      if Application.get_env(:portermills, :log_magic_links, false) do
        Logger.info("Magic link for #{user.email}: #{url}  (app link: portermills://auth?token=#{token})")
      end

      case UserNotifier.deliver_magic_link(user, url) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.error("Could not send magic link to #{user.email}: #{inspect(reason)}")
          {:error, :delivery_failed}
      end
    end
  end

  @doc "Exchanges a raw magic token for its user. A token can be used once."
  def verify_magic_token(token) when is_binary(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    hashed = hash_token(token)

    query =
      from t in MagicToken,
        where: t.token == ^hashed and t.expires_at > ^now and is_nil(t.used_at),
        select: t.user_id

    # A single UPDATE, so two concurrent verifications can't both succeed.
    case Repo.update_all(query, set: [used_at: now]) do
      {1, [user_id]} -> {:ok, Repo.get!(User, user_id)}
      _ -> {:error, :invalid_token}
    end
  end

  def verify_magic_token(_), do: {:error, :invalid_token}

  defp hash_token(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()
end
