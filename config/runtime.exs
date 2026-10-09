import Config

with :dev <- config_env(),
     true <- File.exists?(".env") do
  ".env"
  |> File.stream!()
  |> Enum.each(fn line ->
    case String.trim(line) do
      "" ->
        :ok

      "#" <> _ ->
        :ok

      entry ->
        case String.split(entry, "=", parts: 2) do
          [key, val] ->
            clean_val = val |> String.trim() |> String.trim("\"") |> String.trim("'")
            System.put_env(String.trim(key), clean_val)

          _ ->
            :ok
        end
    end
  end)
end

case System.get_env("GOOGLE_MAPS_API_KEY") do
  nil -> :ok
  "" -> :ok
  key -> config :kfofo, :google_maps, api_key: key
end

case {config_env(), System.get_env("OLX_BASE_URL")} do
  {:test, _} -> :ok
  {_, nil} -> :ok
  {_, ""} -> :ok
  {_, url} -> config :kfofo, :olx_scraper, base_url: url
end

case {config_env(), System.get_env("QUINTOANDAR_BASE_URL")} do
  {:test, _} -> :ok
  {_, nil} -> :ok
  {_, ""} -> :ok
  {_, url} -> config :kfofo, :quintoandar_scraper, base_url: url
end

case System.get_env("PHX_SERVER") do
  nil -> :ok
  "" -> :ok
  _ -> config :kfofo, KfofoWeb.Endpoint, server: true
end

case config_env() do
  :prod ->
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    maybe_ipv6 =
      case System.get_env("ECTO_IPV6") in ~w(true 1) do
        true -> [:inet6]
        false -> []
      end

    config :kfofo, Kfofo.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
      socket_options: maybe_ipv6

    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    host = System.get_env("PHX_HOST") || "example.com"
    port = String.to_integer(System.get_env("PORT") || "4000")

    config :kfofo, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

    config :kfofo, KfofoWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base

  _ ->
    :ok
end
