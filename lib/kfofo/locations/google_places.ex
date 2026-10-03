defmodule Kfofo.Locations.GooglePlaces do
  @moduledoc """
  Client for Google Places API.
  Handles location autocomplete and place details parsing for Brazilian addresses.
  """

  @base_url "https://maps.googleapis.com/maps/api/place"

  @doc """
  Retrieves autocomplete predictions for a given location query.
  """
  def autocomplete(query, opts \\ [])

  def autocomplete(query, _opts) when not is_binary(query) or byte_size(query) < 2, do: {:ok, []}

  def autocomplete(query, opts) do
    with {:ok, api_key} <- get_api_key(opts) do
      params = [
        input: query,
        key: api_key,
        components: "country:br",
        language: "pt-BR",
        types: Keyword.get(opts, :types, "(regions)")
      ]

      fetch_fn = Keyword.get(opts, :http_client, &Req.get/2)
      url = "#{@base_url}/autocomplete/json"

      case fetch_fn.(url, params: params) do
        {:ok, %{status: 200, body: %{"status" => "OK", "predictions" => predictions}}} ->
          {:ok, Enum.map(predictions, &normalize_prediction/1)}

        {:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}} ->
          {:ok, []}

        {:ok, %{status: 200, body: %{"status" => status, "error_message" => message}}} ->
          {:error, {:google_places_error, status, message}}

        {:ok, %{status: 200, body: %{"status" => status}}} ->
          {:error, {:google_places_error, status}}

        {:ok, %{status: http_status}} ->
          {:error, {:http_error, http_status}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end
  end

  @doc """
  Retrieves place details and parses address components into structured location data.
  """
  def place_details(place_id, opts \\ [])

  def place_details(place_id, _opts) when not is_binary(place_id) or byte_size(place_id) == 0 do
    {:error, :invalid_place_id}
  end

  def place_details(place_id, opts) do
    with {:ok, api_key} <- get_api_key(opts) do
      params = [
        place_id: place_id,
        key: api_key,
        fields: "address_components,formatted_address,geometry",
        language: "pt-BR"
      ]

      fetch_fn = Keyword.get(opts, :http_client, &Req.get/2)
      url = "#{@base_url}/details/json"

      case fetch_fn.(url, params: params) do
        {:ok, %{status: 200, body: %{"status" => "OK", "result" => result}}} ->
          {:ok, normalize_details(place_id, result)}

        {:ok, %{status: 200, body: %{"status" => status, "error_message" => message}}} ->
          {:error, {:google_places_error, status, message}}

        {:ok, %{status: 200, body: %{"status" => status}}} ->
          {:error, {:google_places_error, status}}

        {:ok, %{status: http_status}} ->
          {:error, {:http_error, http_status}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end
  end

  @doc """
  Converts a location name into a URL-safe lowercase slug.
  """
  def slugify(nil), do: nil

  def slugify(string) when is_binary(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[\x{0300}-\x{036F}]/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp get_api_key(opts) do
    key =
      case Keyword.fetch(opts, :api_key) do
        {:ok, key} -> key
        :error -> configured_api_key()
      end

    case key do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      valid_key -> {:ok, valid_key}
    end
  end

  defp configured_api_key do
    :kfofo
    |> Application.get_env(:google_maps, [])
    |> Keyword.get(:api_key)
  end

  defp normalize_prediction(pred) do
    formatting = Map.get(pred, "structured_formatting", %{})

    %{
      place_id: Map.get(pred, "place_id"),
      description: Map.get(pred, "description"),
      main_text: Map.get(formatting, "main_text") || Map.get(pred, "description"),
      secondary_text: Map.get(formatting, "secondary_text", ""),
      types: Map.get(pred, "types", [])
    }
  end

  defp normalize_details(place_id, result) do
    components = Map.get(result, "address_components", [])
    geometry = Map.get(result, "geometry", %{})
    location_coords = Map.get(geometry, "location", %{})

    state_comp = find_component(components, "administrative_area_level_1")

    city_comp =
      find_component(components, "administrative_area_level_2") ||
        find_component(components, "locality")

    neighborhood_comp =
      find_component(components, "sublocality_level_1") ||
        find_component(components, "sublocality") ||
        find_component(components, "neighborhood")

    state_code = parse_state_code(state_comp)
    state_name = component_name(state_comp)
    city_name = component_name(city_comp)
    neighborhood_name = component_name(neighborhood_comp)

    %{
      place_id: place_id,
      formatted_address: Map.get(result, "formatted_address", ""),
      state: state_code,
      state_name: state_name,
      city: slugify(city_name),
      city_name: city_name,
      neighborhood: slugify(neighborhood_name),
      neighborhood_name: neighborhood_name,
      lat: Map.get(location_coords, "lat"),
      lng: Map.get(location_coords, "lng")
    }
  end

  defp find_component(components, type) do
    Enum.find(components, fn c ->
      types = Map.get(c, "types", [])
      type in types
    end)
  end

  defp component_name(%{"long_name" => name}), do: name
  defp component_name(%{"short_name" => name}), do: name
  defp component_name(_), do: nil

  defp parse_state_code(%{"short_name" => code}) when is_binary(code) do
    code |> String.trim() |> String.downcase()
  end

  defp parse_state_code(_), do: nil
end
