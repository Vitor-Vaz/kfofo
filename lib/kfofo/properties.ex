defmodule Kfofo.Properties do
  @moduledoc """
  Context for managing and querying real-time properties from the aggregated marketplaces.
  """

  alias Kfofo.Properties.Store

  @doc """
  Gets a single property by its external ID.

  Returns `{:ok, property}` or `{:error, :not_found}`.
  """
  def get_property(external_id) do
    Store.get(external_id)
  end

  @doc """
  Persists a list of properties into the store.
  """
  def save_properties(properties) when is_list(properties) do
    Store.put_all(properties)
  end

  @doc """
  Persists a single property into the store.
  """
  def save_property(property) when is_map(property) do
    Store.put(property)
  end
end
