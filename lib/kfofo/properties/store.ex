defmodule Kfofo.Properties.Store do
  @moduledoc """
  ETS-backed in-memory store for properties fetched from marketplace scrapers.
  Enables fast O(1) lookups for the property details view without re-scraping.
  """

  use GenServer

  @table_name :kfofo_properties_store
  @max_entries 5_000

  @default_property %{
    external_id: "",
    title: "",
    price: nil,
    url: "",
    source: "",
    property_type: nil,
    description: "",
    location: %{},
    details: %{},
    images: [],
    published_at: nil
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Saves a single property map into the ETS store.
  """
  def put(property) when is_map(property) do
    case Map.get(property, :external_id) do
      id when is_binary(id) and id != "" ->
        normalized = Map.merge(@default_property, property)
        :ets.insert(@table_name, {id, normalized})
        trim_if_exceeds_max()
        :ok

      _ ->
        {:error, :missing_external_id}
    end
  end

  def put(_), do: {:error, :invalid_property}

  @doc """
  Saves a list of property maps into the ETS store.
  """
  def put_all(properties) when is_list(properties) do
    entries =
      properties
      |> Enum.filter(fn prop ->
        is_map(prop) and is_binary(Map.get(prop, :external_id)) and
          Map.get(prop, :external_id) != ""
      end)
      |> Enum.map(fn prop ->
        normalized = Map.merge(@default_property, prop)
        {normalized.external_id, normalized}
      end)

    case entries do
      [] ->
        :ok

      _ ->
        :ets.insert(@table_name, entries)
        trim_if_exceeds_max()
        :ok
    end
  end

  def put_all(_), do: {:error, :invalid_properties_list}

  @doc """
  Fetches a property by its `external_id`.
  """
  def get(external_id) when is_binary(external_id) do
    case :ets.lookup(@table_name, external_id) do
      [{^external_id, property}] -> {:ok, property}
      [] -> {:error, :not_found}
    end
  end

  def get(_), do: {:error, :invalid_id}

  @doc """
  Clears all stored properties. Useful for test cleanup.
  """
  def clear do
    case :ets.info(@table_name) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(@table_name)
        :ok
    end
  end

  @doc """
  Returns the count of properties currently stored.
  """
  def count do
    case :ets.info(@table_name, :size) do
      :undefined -> 0
      size when is_integer(size) -> size
    end
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{table: table}}
  end

  defp trim_if_exceeds_max do
    case :ets.info(@table_name, :size) do
      size when is_integer(size) and size > @max_entries ->
        keys_to_drop =
          @table_name
          |> :ets.tab2list()
          |> Enum.take(size - @max_entries)
          |> Enum.map(&elem(&1, 0))

        Enum.each(keys_to_drop, &:ets.delete(@table_name, &1))

      _ ->
        :ok
    end
  end
end
