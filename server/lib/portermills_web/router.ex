defmodule PortermillsWeb.Router do
  use PortermillsWeb, :router

  pipeline :api_public do
    plug :accepts, ["json"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug PortermillsWeb.Auth.Pipeline
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PortermillsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Public endpoints (no auth required)
  scope "/api", PortermillsWeb do
    pipe_through :api_public

    post "/auth/magic-link", AuthController, :request_magic_link
    post "/auth/verify", AuthController, :verify_magic_link
  end

  # Authenticated API endpoints
  scope "/api", PortermillsWeb do
    pipe_through :api

    get "/me", AuthController, :me
    get "/family/members", AuthController, :members

    resources "/calendar/events", CalendarEventController, except: [:new, :edit]

    resources "/list-templates", ListTemplateController, except: [:new, :edit]

    resources "/lists", ListController, except: [:new, :edit] do
      resources "/items", ListItemController, except: [:new, :edit, :show]
    end

    # Declared before the wishlist resources so "items" isn't read as a wishlist id.
    post "/wishlists/items/:id/claim", WishlistItemController, :claim
    delete "/wishlists/items/:id/claim", WishlistItemController, :unclaim

    post "/wishlists/:id/share", WishlistController, :share
    delete "/wishlists/:id/share", WishlistController, :unshare

    resources "/wishlists", WishlistController, only: [:index, :show, :update] do
      resources "/items", WishlistItemController, except: [:new, :edit]
    end
  end

  scope "/", PortermillsWeb do
    pipe_through :browser

    # Landing page for the link in a magic-link email; hands the token to the app.
    get "/auth/magic/:token", MagicLinkController, :show

    # Public, read-only wishlist page, addressed by its share token.
    live "/wishlists/:token", WishlistLive.Show
  end

  if Application.compile_env(:portermills, :log_magic_links, false) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
