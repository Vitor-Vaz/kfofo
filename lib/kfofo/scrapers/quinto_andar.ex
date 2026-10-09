defmodule Kfofo.Scrapers.QuintoAndar do
  @moduledoc """
  Scraper facade module for QuintoAndar Real Estate.
  Orchestrates HTTP fetching via `Kfofo.Scrapers.QuintoAndar.Client` and parsing via `Kfofo.Scrapers.QuintoAndar.Parser`.
  """

  alias Kfofo.Scrapers.QuintoAndar.Client
  alias Kfofo.Scrapers.QuintoAndar.Parser

  @doc """
  Fetches property listings from QuintoAndar based on specified filter options.

  ## Options
    * `:state` - State acronym, e.g. "sp", "rj" (optional)
    * `:city` - City slug or name, e.g. "sao-paulo" (optional)
    * `:neighborhood` - Neighborhood name or slug, e.g. "moema" (optional)
    * `:type` - Transaction type: `:venda` or `:aluguel` (default: `:aluguel`)
    * `:property_type` - Property type: "apartamento", "casa", "quarto" (optional)
    * `:min_price` - Minimum price integer (optional)
    * `:max_price` - Maximum price integer (optional)
    * `:bedrooms` - Minimum bedrooms count (optional)
    * `:garages` - Minimum garage spaces count (optional)
    * `:http_client` - Custom HTTP client function for testing (optional)

  ## Examples

      iex> Kfofo.Scrapers.QuintoAndar.fetch_properties(%{state: "sp", city: "sao-paulo", type: :aluguel})
      {:ok, %{properties: [...], total: 24, page: 1}}

  """
  def fetch_properties(opts \\ %{}) do
    with {:ok, html} <- Client.fetch_search_page(opts),
         {:ok, result} <- Parser.parse_page(html) do
      filtered = apply_in_memory_filters(result.properties, opts)
      {:ok, %{result | properties: filtered, total: length(filtered)}}
    end
  end

  defp apply_in_memory_filters(properties, opts) when is_list(properties) and is_map(opts) do
    properties
    |> filter_by_min_price(opts[:min_price] || opts["min_price"])
    |> filter_by_max_price(opts[:max_price] || opts["max_price"])
    |> filter_by_bedrooms(opts[:bedrooms] || opts["bedrooms"])
    |> filter_by_garages(opts[:garages] || opts["garages"])
  end

  defp apply_in_memory_filters(properties, _), do: properties

  defp filter_by_min_price(properties, nil), do: properties
  defp filter_by_min_price(properties, ""), do: properties

  defp filter_by_min_price(properties, min_price) when is_number(min_price) do
    Enum.filter(properties, fn prop ->
      case prop.price do
        price when is_number(price) -> price >= min_price
        _ -> true
      end
    end)
  end

  defp filter_by_min_price(properties, min_str) when is_binary(min_str) do
    case Integer.parse(min_str) do
      {min, _} -> filter_by_min_price(properties, min)
      _ -> properties
    end
  end

  defp filter_by_max_price(properties, nil), do: properties
  defp filter_by_max_price(properties, ""), do: properties

  defp filter_by_max_price(properties, max_price) when is_number(max_price) do
    Enum.filter(properties, fn prop ->
      case prop.price do
        price when is_number(price) -> price <= max_price
        _ -> true
      end
    end)
  end

  defp filter_by_max_price(properties, max_str) when is_binary(max_str) do
    case Integer.parse(max_str) do
      {max, _} -> filter_by_max_price(properties, max)
      _ -> properties
    end
  end

  defp filter_by_bedrooms(properties, nil), do: properties
  defp filter_by_bedrooms(properties, ""), do: properties

  defp filter_by_bedrooms(properties, min_rooms) when is_number(min_rooms) do
    Enum.filter(properties, fn prop ->
      case prop.details[:rooms] do
        rooms when is_number(rooms) -> rooms >= min_rooms
        _ -> true
      end
    end)
  end

  defp filter_by_bedrooms(properties, rooms_str) when is_binary(rooms_str) do
    case Integer.parse(rooms_str) do
      {rooms, _} -> filter_by_bedrooms(properties, rooms)
      _ -> properties
    end
  end

  defp filter_by_garages(properties, nil), do: properties
  defp filter_by_garages(properties, ""), do: properties

  defp filter_by_garages(properties, min_garages) when is_number(min_garages) do
    Enum.filter(properties, fn prop ->
      case prop.details[:garage_spaces] do
        garages when is_number(garages) -> garages >= min_garages
        _ -> true
      end
    end)
  end

  defp filter_by_garages(properties, garages_str) when is_binary(garages_str) do
    case Integer.parse(garages_str) do
      {garages, _} -> filter_by_garages(properties, garages)
      _ -> properties
    end
  end

  defdelegate build_url(opts \\ %{}), to: Client
  defdelegate parse_page(html), to: Parser
  defdelegate extract_next_data(html), to: Parser
  defdelegate parse_next_data(json), to: Parser
  defdelegate normalize_house(house), to: Parser
end
