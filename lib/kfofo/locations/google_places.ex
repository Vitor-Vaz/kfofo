defmodule Kfofo.Locations.GooglePlaces do
  @moduledoc """
  Client for Google Places API (New).
  Handles location autocomplete and place details parsing for Brazilian addresses.
  """

  @base_url "https://places.googleapis.com/v1"

  @doc """
  Retrieves autocomplete predictions for a given location query via Places API (New).
  """
  def autocomplete(query, opts \\ [])

  def autocomplete(query, _opts) when not is_binary(query) or byte_size(query) < 2, do: {:ok, []}

  def autocomplete(query, opts) do
    with {:ok, api_key} <- get_api_key(opts) do
      url = "#{@base_url}/places:autocomplete"

      headers = [
        {"content-type", "application/json"},
        {"x-goog-api-key", api_key}
      ]

      payload = %{
        "input" => query,
        "includedRegionCodes" => ["br"],
        "includedPrimaryTypes" => ["(regions)"],
        "languageCode" => "pt-BR"
      }

      fetch_fn = Keyword.get(opts, :http_client, &Req.post/2)

      case fetch_fn.(url, json: payload, headers: headers) do
        {:ok, %{status: 200, body: %{"suggestions" => suggestions}}} when is_list(suggestions) ->
          predictions =
            suggestions
            |> Enum.map(&normalize_new_prediction/1)
            |> Enum.reject(&is_nil/1)

          {:ok, predictions}

        {:ok, %{status: 200, body: %{"suggestions" => []}}} ->
          {:ok, []}

        {:ok, %{status: 200, body: %{"predictions" => legacy_predictions}}}
        when is_list(legacy_predictions) ->
          {:ok, Enum.map(legacy_predictions, &normalize_legacy_prediction/1)}

        {:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}} ->
          {:ok, []}

        {:ok, %{status: 200, body: %{}}} ->
          {:ok, []}

        {:ok, %{status: 200, body: %{"error" => %{"message" => msg, "status" => status}}}} ->
          {:error, {:google_places_error, status, msg}}

        {:ok, %{status: status_code, body: %{"error" => %{"message" => msg, "status" => status}}}}
        when status_code >= 400 ->
          {:error, {:google_places_error, status, msg}}

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
      clean_place_id = String.replace_prefix(place_id, "places/", "")
      url = "#{@base_url}/places/#{clean_place_id}"

      headers = [
        {"x-goog-api-key", api_key},
        {"x-goog-fieldmask", "id,displayName,formattedAddress,addressComponents,location"}
      ]

      params = [languageCode: "pt-BR"]
      fetch_fn = Keyword.get(opts, :http_client, &Req.get/2)

      case fetch_fn.(url, params: params, headers: headers) do
        {:ok, %{status: 200, body: %{"id" => _} = result}} ->
          {:ok, normalize_new_details(clean_place_id, result)}

        {:ok, %{status: 200, body: %{"result" => legacy_result}}} ->
          {:ok, normalize_legacy_details(clean_place_id, legacy_result)}

        {:ok, %{status: status_code, body: %{"error" => %{"message" => msg, "status" => status}}}}
        when status_code >= 400 ->
          {:error, {:google_places_error, status, msg}}

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

  @disallowed_prediction_types [
    "establishment",
    "point_of_interest",
    "shopping_mall",
    "store",
    "food",
    "restaurant",
    "lodging",
    "tourist_attraction",
    "country"
  ]

  defp normalize_new_prediction(%{"placePrediction" => pred}) do
    types = Map.get(pred, "types", [])

    case valid_location_prediction?(types) do
      true ->
        struct_format = Map.get(pred, "structuredFormat", %{})
        text_obj = Map.get(pred, "text", %{})

        %{
          place_id: Map.get(pred, "placeId"),
          description: Map.get(text_obj, "text") || "",
          main_text:
            get_in(struct_format, ["mainText", "text"]) || Map.get(text_obj, "text") || "",
          secondary_text: get_in(struct_format, ["secondaryText", "text"]) || "",
          types: types
        }

      false ->
        nil
    end
  end

  defp normalize_new_prediction(_), do: nil

  defp normalize_legacy_prediction(pred) do
    types = Map.get(pred, "types", [])

    case valid_location_prediction?(types) do
      true ->
        formatting = Map.get(pred, "structured_formatting", %{})

        %{
          place_id: Map.get(pred, "place_id"),
          description: Map.get(pred, "description"),
          main_text: Map.get(formatting, "main_text") || Map.get(pred, "description"),
          secondary_text: Map.get(formatting, "secondary_text", ""),
          types: types
        }

      false ->
        nil
    end
  end

  defp valid_location_prediction?(types) when is_list(types) do
    not Enum.any?(types, &(&1 in @disallowed_prediction_types))
  end

  defp valid_location_prediction?(_), do: true

  defp normalize_new_details(place_id, result) do
    components = Map.get(result, "addressComponents", [])
    location_coords = Map.get(result, "location", %{})

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
      formatted_address: Map.get(result, "formattedAddress", ""),
      state: state_code,
      state_name: state_name,
      city: slugify(city_name),
      city_name: city_name,
      neighborhood: slugify(neighborhood_name),
      neighborhood_name: neighborhood_name,
      lat: Map.get(location_coords, "latitude"),
      lng: Map.get(location_coords, "longitude")
    }
  end

  defp normalize_legacy_details(place_id, result) do
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

  defp component_name(%{"longText" => name}), do: name
  defp component_name(%{"shortText" => name}), do: name
  defp component_name(%{"long_name" => name}), do: name
  defp component_name(%{"short_name" => name}), do: name
  defp component_name(_), do: nil

  defp parse_state_code(%{"shortText" => code}) when is_binary(code) do
    code |> String.trim() |> String.downcase()
  end

  defp parse_state_code(%{"short_name" => code}) when is_binary(code) do
    code |> String.trim() |> String.downcase()
  end

  defp parse_state_code(_), do: nil
end
