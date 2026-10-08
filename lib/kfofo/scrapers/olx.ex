defmodule Kfofo.Scrapers.Olx do
  @moduledoc """
  Scraper facade module for OLX Real Estate (Imóveis).
  Orchestrates HTTP fetching via `Kfofo.Scrapers.Olx.Client` and parsing via `Kfofo.Scrapers.Olx.Parser`.
  """

  alias Kfofo.Scrapers.Olx.Client
  alias Kfofo.Scrapers.Olx.Parser

  @doc """
  Fetches property listings from OLX based on specified filter options.

  ## Options
    * `:state` - State acronym, e.g. "sp", "rj" (optional)
    * `:region` - Region slug, e.g. "sao-paulo-e-regiao" (optional)
    * `:city` - City slug, e.g. "sao-paulo" (optional)
    * `:neighborhood` - Neighborhood name or slug, e.g. "moema" (optional)
    * `:type` - Transaction type: `:venda` or `:aluguel` (default: `:venda`)
    * `:category` - Property category, e.g. "imoveis" (default: "imoveis")
    * `:min_price` - Minimum price integer (optional)
    * `:max_price` - Maximum price integer (optional)
    * `:bedrooms` - Minimum bedrooms count (optional)
    * `:page` - Page number integer (default: 1)
    * `:http_client` - Custom HTTP client function for testing (optional)

  ## Examples

      iex> Kfofo.Scrapers.Olx.fetch_properties(%{state: "sp", city: "sao-paulo", type: :venda})
      {:ok, %{properties: [...], total: 50, page: 1}}

  """
  def fetch_properties(opts \\ %{}) do
    with {:ok, html} <- Client.fetch_search_page(opts),
         {:ok, result} <- Parser.parse_page(html) do
      filtered = filter_by_state(result.properties, opts)
      {:ok, %{result | properties: filtered, total: length(filtered)}}
    end
  end

  defp filter_by_state(properties, opts) when is_list(properties) and is_map(opts) do
    apply_state_filter(properties, get_clean_opt(opts, :state))
  end

  defp filter_by_state(properties, _), do: properties

  defp apply_state_filter(properties, nil), do: properties

  defp apply_state_filter(properties, target_state) do
    Enum.filter(properties, &matches_state?(&1, target_state))
  end

  defp matches_state?(%{location: %{state: nil}}, _target), do: true
  defp matches_state?(%{location: %{state: ""}}, _target), do: true

  defp matches_state?(%{location: %{state: state}}, target) when is_binary(state) do
    String.downcase(state) == target
  end

  defp matches_state?(%{location: %{state: state}}, target) when is_atom(state) do
    state |> to_string() |> String.downcase() == target
  end

  defp matches_state?(_property, _target), do: true

  defp get_clean_opt(opts, key) when is_map(opts) do
    clean_opt_val(Map.get(opts, key) || Map.get(opts, to_string(key)))
  end

  defp get_clean_opt(_, _), do: nil

  defp clean_opt_val(nil), do: nil
  defp clean_opt_val(""), do: nil
  defp clean_opt_val(str) when is_binary(str), do: str |> String.trim() |> String.downcase()
  defp clean_opt_val(atom) when is_atom(atom), do: atom |> to_string() |> String.downcase()
  defp clean_opt_val(_), do: nil

  defdelegate build_url(opts \\ %{}), to: Client
  defdelegate parse_page(html), to: Parser
  defdelegate parse_html_cards(html), to: Parser
  defdelegate extract_next_data(html), to: Parser
  defdelegate parse_next_data(json), to: Parser
  defdelegate normalize_ad(ad), to: Parser
  defdelegate normalize_card(card), to: Parser
  defdelegate normalize_card(card, images_map), to: Parser
  defdelegate extract_rsc_images_map(html), to: Parser
end
