defmodule Kfofo.Locations do
  @moduledoc """
  Context module for location queries and geocoding services.
  """

  alias Kfofo.Locations.GooglePlaces

  @doc """
  Searches for location suggestions matching the given query string.
  """
  def search_locations(query, opts \\ []) do
    GooglePlaces.autocomplete(query, opts)
  end

  @doc """
  Fetches full structured location details for a given Google Place ID.
  """
  def get_location_details(place_id, opts \\ []) do
    GooglePlaces.place_details(place_id, opts)
  end

  @doc """
  Converts a location name into a URL-friendly slug.
  """
  defdelegate slugify(string), to: GooglePlaces
end
