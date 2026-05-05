defmodule PortermillsWeb.Router do
  use PortermillsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug PortermillsWeb.Auth.Pipeline
  end

  pipeline :api_public do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
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

    resources "/calendar/events", CalendarEventController, except: [:new, :edit]

    resources "/lists", ListController, except: [:new, :edit] do
      resources "/items", ListItemController, except: [:new, :edit, :show]
    end

    resources "/wishlists", WishlistController, only: [:index, :show] do
      resources "/items", WishlistItemController, except: [:new, :edit]
    end

    post "/wishlists/items/:id/claim", WishlistItemController, :claim
    delete "/wishlists/items/:id/claim", WishlistItemController, :unclaim
  end

  # LiveView (web-facing features for non-app access)
  scope "/", PortermillsWeb do
    pipe_through :browser

    live "/wishlists/:id", WishlistLive.Show
  end
end
