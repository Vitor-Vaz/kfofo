defmodule Kfofo.Scrapers.QuintoAndar.Client do
  @moduledoc """
  HTTP Client for QuintoAndar marketplace.
  Handles dynamic search URL construction and HTTP fetching.
  """

  @default_user_agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

  @doc """
  Fetches HTML content from QuintoAndar search endpoint.
  """
  def fetch_search_page(opts \\ %{}) do
    opts = normalize_opts(opts)
    url = build_url(opts)
    headers = default_headers()
    fetch_fn = Map.get(opts, :http_client, &default_fetch/2)

    case fetch_fn.(url, headers) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, body} when is_binary(body) -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, {:network_error, reason}}
      error -> error
    end
  end

  @doc """
  Builds search URL dynamically for QuintoAndar without imperative if statements.
  """
  def build_url(opts \\ %{}) do
    opts = normalize_opts(opts)
    base_url = config_val(:base_url)

    type_path = transaction_path(Map.get(opts, :type))
    location_slug = build_location_slug(opts)
    property_type = property_type_path(Map.get(opts, :property_type))
    bedrooms_part = bedrooms_path(Map.get(opts, :bedrooms))
    garages_part = garages_path(Map.get(opts, :garages) || Map.get(opts, :garage_spaces))

    path_parts =
      [type_path, "imovel", location_slug]
      |> maybe_append(property_type, & &1)
      |> maybe_append(bedrooms_part, & &1)
      |> maybe_append(garages_part, & &1)

    path = Enum.join(path_parts, "/")
    query_params = build_query_params(opts)

    format_url(base_url, path, query_params)
  end

  defp default_fetch(url, headers) do
    script_path = Path.join(:code.priv_dir(:kfofo), "scrapers/fetch_olx.mjs")

    case System.cmd("node", [script_path, url], stderr_to_stdout: false) do
      {body, 0} when is_binary(body) and byte_size(body) > 0 ->
        {:ok, body}

      _ ->
        case Req.get(url, headers: headers, retry: :safe_transient) do
          {:ok, %Req.Response{status: 200, body: body}} ->
            {:ok, body}

          {:ok, %Req.Response{status: status}} ->
            {:error, {:http_error, status}}

          {:error, reason} ->
            {:error, {:network_error, reason}}
        end
    end
  end

  defp default_headers do
    [
      {"user-agent", @default_user_agent},
      {"accept",
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"},
      {"accept-language", "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"},
      {"sec-ch-ua",
       "\"Google Chrome\";v=\"123\", \"Not:A-Brand\";v=\"8\", \"Chromium\";v=\"123\""},
      {"sec-ch-ua-mobile", "?0"},
      {"sec-ch-ua-platform", "\"Linux\""},
      {"sec-fetch-dest", "document"},
      {"sec-fetch-mode", "navigate"},
      {"sec-fetch-site", "none"},
      {"sec-fetch-user", "?1"},
      {"upgrade-insecure-requests", "1"}
    ]
  end

  defp transaction_path(:venda), do: "comprar"
  defp transaction_path("venda"), do: "comprar"
  defp transaction_path(_), do: "alugar"

  defp build_location_slug(opts) do
    neighborhood = clean_slug(Map.get(opts, :neighborhood))
    city = clean_slug(Map.get(opts, :city))
    state = clean_slug(Map.get(opts, :state))

    assemble_location_slug(neighborhood, city, state)
  end

  defp assemble_location_slug(neighborhood, city, state)
       when is_binary(neighborhood) and is_binary(city) and is_binary(state) do
    "#{neighborhood}-#{city}-#{state}-brasil"
  end

  defp assemble_location_slug(nil, city, state) when is_binary(city) and is_binary(state) do
    "#{city}-#{state}-brasil"
  end

  defp assemble_location_slug(nil, nil, state) when is_binary(state) do
    "#{state}-brasil"
  end

  defp assemble_location_slug(_neighborhood, _city, _state) do
    "sao-paulo-sp-brasil"
  end

  defp property_type_path("casa"), do: "casas"
  defp property_type_path("casas"), do: "casas"
  defp property_type_path(:casa), do: "casas"
  defp property_type_path("apartamento"), do: "apartamentos"
  defp property_type_path("apartamentos"), do: "apartamentos"
  defp property_type_path(:apartamento), do: "apartamentos"
  defp property_type_path("quarto"), do: "kitnets-e-studios"
  defp property_type_path("quartos"), do: "kitnets-e-studios"
  defp property_type_path(:quarto), do: "kitnets-e-studios"
  defp property_type_path(_), do: nil

  defp bedrooms_path(1), do: "1-quarto"
  defp bedrooms_path("1"), do: "1-quarto"
  defp bedrooms_path(n) when is_integer(n) and n > 1, do: "#{n}-quartos"

  defp bedrooms_path(n) when is_binary(n) do
    case Integer.parse(n) do
      {1, _} -> "1-quarto"
      {val, _} when val > 1 -> "#{val}-quartos"
      _ -> nil
    end
  end

  defp bedrooms_path(_), do: nil

  defp garages_path(1), do: "1-vaga"
  defp garages_path("1"), do: "1-vaga"
  defp garages_path(n) when is_integer(n) and n > 1, do: "#{n}-vagas"

  defp garages_path(n) when is_binary(n) do
    case Integer.parse(n) do
      {1, _} -> "1-vaga"
      {val, _} when val > 1 -> "#{val}-vagas"
      _ -> nil
    end
  end

  defp garages_path(_), do: nil

  defp format_url(base_url, path, []), do: "#{base_url}/#{path}"

  defp format_url(base_url, path, query_params) do
    "#{base_url}/#{path}?#{URI.encode_query(query_params)}"
  end

  defp build_query_params(opts) do
    []
    |> maybe_put_query("price_min", Map.get(opts, :min_price))
    |> maybe_put_query("price_max", Map.get(opts, :max_price))
  end

  defp clean_slug(nil), do: nil
  defp clean_slug(""), do: nil

  defp clean_slug(val) when is_binary(val) do
    val
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/\s+/, "-")
  end

  defp clean_slug(atom) when is_atom(atom), do: clean_slug(to_string(atom))
  defp clean_slug(_), do: nil

  defp maybe_append(list, nil, _func), do: list
  defp maybe_append(list, "", _func), do: list
  defp maybe_append(list, value, func), do: list ++ [func.(value)]

  defp maybe_put_query(acc, _key, nil), do: acc
  defp maybe_put_query(acc, _key, ""), do: acc
  defp maybe_put_query(acc, key, value), do: acc ++ [{key, to_string(value)}]

  defp normalize_opts(opts) when is_map(opts) do
    Map.new(opts, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> opts
  end

  defp normalize_opts(opts), do: opts

  defp config_val(key) do
    :kfofo
    |> Application.get_env(:quintoandar_scraper, [])
    |> Keyword.get(key, default_config(key))
  end

  defp default_config(:base_url), do: System.get_env("QUINTOANDAR_BASE_URL") || ""
  defp default_config(_), do: nil
end
