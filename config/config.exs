import Config

config :kfofo,
  ecto_repos: [Kfofo.Repo],
  generators: [timestamp_type: :utc_datetime]

config :kfofo, KfofoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KfofoWeb.ErrorHTML, json: KfofoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kfofo.PubSub,
  live_view: [signing_salt: "7XXc5t1Z"]

config :kfofo, Kfofo.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.17.11",
  kfofo: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  kfofo: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :kfofo, :olx_scraper, base_url: System.get_env("OLX_BASE_URL") || "https://www.olx.com.br"

config :kfofo, :quintoandar_scraper,
  base_url: System.get_env("QUINTOANDAR_BASE_URL") || "https://www.quintoandar.com.br"

config :kfofo, :google_maps, api_key: System.get_env("GOOGLE_MAPS_API_KEY")

import_config "#{config_env()}.exs"
