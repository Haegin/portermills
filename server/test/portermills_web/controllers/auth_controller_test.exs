defmodule PortermillsWeb.AuthControllerTest do
  use PortermillsWeb.ConnCase, async: true
  import Swoosh.TestAssertions

  setup :two_families

  test "requesting a magic link emails one, and its token signs in", %{conn: conn, user: user} do
    conn = post(conn, "/api/auth/magic-link", %{email: user.email})
    assert %{"message" => _} = json_response(conn, 200)

    assert_email_sent(fn email ->
      [_, token] = Regex.run(~r{/auth/magic/(\S+)}, email.text_body)
      send(self(), {:token, token})
    end)

    assert_received {:token, token}

    conn = post(build_conn(), "/api/auth/verify", %{token: token})
    assert %{"token" => jwt, "user" => body} = json_response(conn, 200)

    assert body == %{
             "id" => user.id,
             "name" => user.name,
             "email" => user.email,
             "role" => "member",
             "family_id" => user.family_id
           }

    # The JWT works, and the magic token doesn't work twice.
    conn = build_conn() |> put_req_header("authorization", "Bearer " <> jwt) |> get("/api/me")
    assert json_response(conn, 200)["user"]["id"] == user.id

    assert json_response(post(build_conn(), "/api/auth/verify", %{token: token}), 401)
  end

  test "an unknown email gets the same answer and no email", %{conn: conn} do
    conn = post(conn, "/api/auth/magic-link", %{email: "nobody@example.com"})
    assert %{"message" => _} = json_response(conn, 200)
    assert_no_email_sent()
  end

  test "bad requests", %{conn: conn} do
    assert json_response(post(conn, "/api/auth/magic-link", %{}), 400)
    assert json_response(post(conn, "/api/auth/verify", %{}), 400)
    assert json_response(post(conn, "/api/auth/verify", %{token: "wrong"}), 401)
  end

  test "authenticated endpoints reject a missing or bad token", %{conn: conn} do
    assert json_response(get(conn, "/api/me"), 401)

    conn = conn |> put_req_header("authorization", "Bearer nonsense") |> get("/api/lists")
    assert json_response(conn, 401)
  end

  test "members lists only the caller's family", %{conn: conn, user: user} do
    names = conn |> authed(user) |> get("/api/family/members") |> json_response(200) |> Enum.map(& &1["name"])
    assert names == ["Alex", "Sam"]
  end

  test "the magic-link landing page hands the token to the app", %{conn: conn} do
    token = String.duplicate("a", 43)
    assert html_response(get(conn, "/auth/magic/#{token}"), 200) =~ "portermills://auth?token=#{token}"
    assert response(get(conn, "/auth/magic/%22%3E%3Cscript%3E"), 404)
  end
end
