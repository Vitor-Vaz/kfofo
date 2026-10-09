defmodule Kfofo.Scrapers do
  @moduledoc """
  Unified Scrapers orchestrator and aggregator.
  Executes concurrent property searches across multiple marketplaces (OLX, QuintoAndar)
  and merges the results into a consolidated list.
  """

  alias Kfofo.Scrapers.Olx
  alias Kfofo.Scrapers.QuintoAndar

  @scrapers [
    {:olx, &Olx.fetch_properties/1},
    {:quintoandar, &QuintoAndar.fetch_properties/1}
  ]

  @doc """
  Fetches properties from all configured marketplace scrapers in parallel.

  ## Options
    * `:state` - State acronym (e.g. "sp", "rj")
    * `:city` - City name or slug
    * `:neighborhood` - Neighborhood name or slug
    * `:type` - `:venda` or `:aluguel`
    * `:property_type` - "apartamento", "casa", "quarto"
    * `:source` - "olx", "quintoandar", or "all" (default: "all")
    * `:min_price` - Minimum price
    * `:max_price` - Maximum price
    * `:bedrooms` - Bedrooms count
    * `:garages` - Garages count
    * `:scrapers` - Custom list of scrapers for testing (optional)

  ## Examples

      iex> Kfofo.Scrapers.fetch_all_properties(%{state: "sp", city: "sao-paulo", source: "quintoandar"})
      {:ok, %{properties: [...], total: 24}}

  """
  def fetch_all_properties(opts \\ %{}) do
    source_filter = get_source_opt(opts)

    scrapers =
      opts
      |> Map.get(:scrapers, @scrapers)
      |> filter_scrapers_by_source(source_filter)

    tasks =
      Enum.map(scrapers, fn {name, fetch_fn} ->
        Task.async(fn ->
          case fetch_fn.(opts) do
            {:ok, %{properties: props}} -> {name, {:ok, props}}
            {:error, reason} -> {name, {:error, reason}}
            _ -> {name, {:error, :unknown_error}}
          end
        end)
      end)

    results =
      tasks
      |> Task.await_many(15_000)
      |> Enum.map(fn {_name, res} -> res end)

    property_lists =
      Enum.map(results, fn
        {:ok, props} when is_list(props) -> props
        _ -> []
      end)

    successful_properties =
      property_lists
      |> interleave_or_dedup()
      |> filter_properties_by_source(source_filter)

    case {successful_properties, results} do
      {[], [{:error, first_reason} | _]} ->
        {:error, first_reason}

      {props, _} ->
        {:ok,
         %{
           properties: props,
           total: length(props),
           page: 1
         }}
    end
  end

  defp get_source_opt(opts) when is_map(opts) do
    normalize_source(Map.get(opts, :source) || Map.get(opts, "source"))
  end

  defp get_source_opt(_), do: nil

  defp normalize_source("olx"), do: "olx"
  defp normalize_source(:olx), do: "olx"
  defp normalize_source("quintoandar"), do: "quintoandar"
  defp normalize_source(:quintoandar), do: "quintoandar"
  defp normalize_source(_), do: nil

  defp filter_scrapers_by_source(scrapers, nil), do: scrapers

  defp filter_scrapers_by_source(scrapers, "olx") do
    Enum.filter(scrapers, fn {name, _} -> name in [:olx, "olx"] end)
  end

  defp filter_scrapers_by_source(scrapers, "quintoandar") do
    Enum.filter(scrapers, fn {name, _} -> name in [:quintoandar, "quintoandar"] end)
  end

  defp filter_scrapers_by_source(scrapers, _), do: scrapers

  defp filter_properties_by_source(properties, nil), do: properties

  defp filter_properties_by_source(properties, target_source) when is_binary(target_source) do
    Enum.filter(properties, fn prop ->
      to_string(prop[:source] || "") == target_source
    end)
  end

  defp interleave_or_dedup(property_lists) when is_list(property_lists) do
    property_lists
    |> interleave_lists()
    |> Enum.uniq_by(& &1.external_id)
  end

  defp interleave_lists(lists) do
    lists
    |> Enum.reject(&Enum.empty?/1)
    |> case do
      [] ->
        []

      non_empty ->
        heads = Enum.map(non_empty, &hd/1)
        tails = Enum.map(non_empty, &tl/1)
        heads ++ interleave_lists(tails)
    end
  end
end
