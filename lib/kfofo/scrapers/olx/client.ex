defmodule Kfofo.Scrapers.Olx.Client do
  @moduledoc """
  HTTP Client for OLX marketplace.
  Handles URL building and HTTP requests.
  """

  @default_user_agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

  @doc """
  Fetches HTML content from OLX search endpoint.
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
  Builds search URL dynamically without imperative if statements.
  """
  def build_url(opts \\ %{}) do
    opts = normalize_opts(opts)
    base_url = config_val(:base_url)

    category = Map.get(opts, :category, "imoveis")
    type = transaction_type(Map.get(opts, :type))

    path_parts =
      [category, type]
      |> maybe_append(Map.get(opts, :state), &"estado-#{&1}")
      |> maybe_append(Map.get(opts, :region), & &1)
      |> maybe_append(Map.get(opts, :city), & &1)

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

  defp transaction_type(:aluguel), do: "aluguel"
  defp transaction_type(_), do: "venda"

  defp format_url(base_url, path, []), do: "#{base_url}/#{path}"

  defp format_url(base_url, path, query_params) do
    "#{base_url}/#{path}?#{URI.encode_query(query_params)}"
  end

  defp build_query_params(opts) do
    []
    |> maybe_put_query("sf", Map.get(opts, :sf) && "1")
    |> maybe_put_query("ps", Map.get(opts, :min_price))
    |> maybe_put_query("pe", Map.get(opts, :max_price))
    |> maybe_put_query("ros", Map.get(opts, :bedrooms))
    |> maybe_put_query("o", page_param(Map.get(opts, :page)))
  end

  defp page_param(page) when is_integer(page) and page > 1, do: page
  defp page_param(_), do: nil

  defp maybe_append(list, nil, _func), do: list
  defp maybe_append(list, "", _func), do: list
  defp maybe_append(list, value, func), do: list ++ [func.(value)]

  defp maybe_put_query(acc, _key, nil), do: acc
  defp maybe_put_query(acc, _key, false), do: acc
  defp maybe_put_query(acc, key, value), do: acc ++ [{key, to_string(value)}]

  defp normalize_opts(opts) when is_map(opts) do
    Map.new(opts, fn {k, v} -> {to_atom(k), clean_opt(v)} end)
  end

  defp to_atom(atom) when is_atom(atom), do: atom

  defp to_atom(str) when is_binary(str) do
    String.to_existing_atom(str)
  rescue
    _ -> String.to_atom(str)
  end

  defp clean_opt(val) when is_binary(val), do: val |> String.trim() |> String.downcase()
  defp clean_opt(val), do: val

  defp config_val(key) do
    :kfofo
    |> Application.fetch_env!(:olx_scraper)
    |> Keyword.fetch!(key)
  end
end
