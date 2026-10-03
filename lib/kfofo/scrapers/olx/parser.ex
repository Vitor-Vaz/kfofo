defmodule Kfofo.Scrapers.Olx.Parser do
  @moduledoc """
  Parser module for OLX HTML and JSON payloads.
  Converts raw DOM/JSON into normalized property data structures.
  """

  @doc """
  Parses HTML string and extracts the `__NEXT_DATA__` JSON payload.
  """
  def extract_next_data(html) when is_binary(html) do
    with {:ok, document} <- Floki.parse_document(html),
         [script_node] <- Floki.find(document, "#__NEXT_DATA__"),
         json_str <- get_script_text(script_node),
         {:ok, decoded} <- Jason.decode(String.trim(json_str)) do
      {:ok, decoded}
    else
      [] -> {:error, :next_data_script_not_found}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  @doc """
  Parses raw `__NEXT_DATA__` map and returns normalized properties.
  """
  def parse_next_data(%{} = json) do
    case extract_ads_list(json) do
      ads when is_list(ads) and ads != [] ->
        properties = Enum.map(ads, &normalize_ad/1)
        page_info = extract_page_info(json)

        {:ok,
         %{
           properties: properties,
           total: Map.get(page_info, :total, length(properties)),
           page: Map.get(page_info, :page, 1),
           page_size: Map.get(page_info, :page_size, length(properties))
         }}

      _ ->
        {:error, :no_ads_found}
    end
  end

  @doc """
  Normalizes a raw OLX ad map into a standard Property schema map.
  """
  def normalize_ad(ad) when is_map(ad) do
    price = parse_price(Map.get(ad, "price") || Map.get(ad, "priceValue"))
    location = extract_location(ad)

    %{
      external_id: to_string(Map.get(ad, "listId") || Map.get(ad, "id") || Map.get(ad, "adId")),
      title: Map.get(ad, "title") || Map.get(ad, "subject") || "",
      price: price,
      url: Map.get(ad, "url", ""),
      source: "olx",
      description: Map.get(ad, "body") || Map.get(ad, "description") || "",
      location: location,
      details: extract_details(ad),
      images: extract_images(Map.get(ad, "images")),
      published_at:
        Map.get(ad, "date") || Map.get(ad, "dateRaw") || Map.get(ad, "userPublicationDate")
    }
  end

  defp get_script_text({"script", _attrs, children}) when is_list(children) do
    Enum.map_join(children, "", fn
      text when is_binary(text) -> text
      other -> Floki.text(other)
    end)
  end

  defp get_script_text(_), do: ""

  defp extract_ads_list(json) do
    get_in(json, ["props", "pageProps", "ads"]) ||
      get_in(json, ["props", "pageProps", "initialState", "adList", "ads"]) ||
      get_in(json, ["props", "pageProps", "data", "ads"]) ||
      []
  end

  defp extract_page_info(json) do
    page_props = get_in(json, ["props", "pageProps"]) || %{}
    total = page_props["totalAds"] || page_props["total"]
    page = page_props["page"] || page_props["currentPage"]
    page_size = page_props["pageSize"]

    %{total: total, page: page, page_size: page_size}
  end

  defp parse_price(nil), do: nil
  defp parse_price(price) when is_number(price), do: price

  defp parse_price(price) when is_binary(price) do
    integer_part = price |> String.split(",") |> List.first()
    digits_only = String.replace(integer_part, ~r/\D/, "")

    case Integer.parse(digits_only) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp extract_location(ad) do
    location_data = Map.get(ad, "location") || %{}
    properties_data = Map.get(ad, "properties") || []

    %{
      state: location_data["uf"] || find_property_val(properties_data, "uf"),
      city: location_data["municipality"] || find_property_val(properties_data, "municipality"),
      neighborhood:
        location_data["neighbourhood"] || find_property_val(properties_data, "neighbourhood"),
      zipcode: location_data["zipcode"] || find_property_val(properties_data, "zipcode")
    }
  end

  defp extract_details(ad) do
    properties_data = Map.get(ad, "properties") || []

    %{
      bedrooms: parse_int(find_property_val(properties_data, "rooms") || ad["rooms"]),
      bathrooms: parse_int(find_property_val(properties_data, "bathrooms") || ad["bathrooms"]),
      garage_spaces:
        parse_int(find_property_val(properties_data, "garage_spaces") || ad["garage_spaces"]),
      area_sqm: parse_int(find_property_val(properties_data, "size") || ad["size"])
    }
  end

  defp find_property_val(properties, name) when is_list(properties) do
    case Enum.find(properties, fn p -> p["name"] == name end) do
      %{"value" => val} -> val
      _ -> nil
    end
  end

  defp find_property_val(_, _), do: nil

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp extract_images(images) when is_list(images) do
    Enum.map(images, fn
      %{"original" => url} -> url
      %{"url" => url} -> url
      url when is_binary(url) -> url
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_images(_), do: []
end
