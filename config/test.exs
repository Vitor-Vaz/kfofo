import Config

config :kfofo, Kfofo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "kfofo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :kfofo, KfofoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "C5ZKXFA/i00V5cedS1Gc7LdgDk9YAcYs5A7S+bZ5GOywXiNG+I7m1+CjekenXM2b",
  server: false

config :kfofo, Kfofo.Mailer, adapter: Swoosh.Adapters.Test

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :kfofo, :olx_scraper, base_url: "https://dummy-olx.test"

config :kfofo, :quintoandar_scraper, base_url: "https://dummy-quintoandar.test"

config :kfofo, :google_maps, api_key: "dummy_test_key"
