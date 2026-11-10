defmodule PortermillsWeb.Layouts do
  use Phoenix.Component

  attr :inner_content, :any, required: true

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <meta name="robots" content="noindex" />
        <title>Porter-Mills</title>
        <style>
          body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1.25rem; color: #1c1b1f; }
          h1 { font-size: 1.6rem; }
          ul { list-style: none; padding: 0; }
          li { padding: .9rem 0; border-bottom: 1px solid #e3e3e3; }
          .name { font-weight: 600; }
          .meta, .empty { color: #666; font-size: .9rem; }
          a { color: #2f6f5e; }
        </style>
        <script defer src="/assets/phoenix/phoenix.min.js"></script>
        <script defer src="/assets/phoenix_live_view/phoenix_live_view.min.js"></script>
        <script>
          window.addEventListener("DOMContentLoaded", function () {
            var token = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: token}});
            liveSocket.connect();
          });
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end

  attr :inner_content, :any, required: true

  def app(assigns) do
    ~H"""
    <main>{@inner_content}</main>
    """
  end
end
