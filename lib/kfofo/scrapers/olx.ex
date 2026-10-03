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
         {:ok, json} <- Parser.extract_next_data(html),
         {:ok, result} <- Parser.parse_next_data(json) do
      {:ok, result}
    end
  end

  defdelegate build_url(opts \\ %{}), to: Client
  defdelegate extract_next_data(html), to: Parser
  defdelegate parse_next_data(json), to: Parser
  defdelegate normalize_ad(ad), to: Parser
end
