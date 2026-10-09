defmodule Kfofo.Scrapers.QuintoAndar.Parser do
  @moduledoc """
  Parser module for QuintoAndar HTML and __NEXT_DATA__ JSON payloads.
  Converts raw DOM/JSON into normalized Property data structures.
  """

  @doc """
  Parses HTML document containing QuintoAndar __NEXT_DATA__ script tag.
  """
  def parse_page(html) when is_binary(html) do
    with {:ok, json} <- extract_next_data(html),
         {:ok, result} <- parse_next_data(json) do
      {:ok, result}
    end
  end

  @doc """
  Extracts and decodes the JSON payload from the __NEXT_DATA__ script tag.
  """
  def extract_next_data(html) when is_binary(html) do
    case Regex.run(
           ~r/<script\s+id="__NEXT_DATA__"\s+type="application\/json">([\s\S]*?)<\/script>/,
           html
         ) do
      [_, json_str] ->
        case Jason.decode(json_str) do
          {:ok, json} -> {:ok, json}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      _ ->
        {:error, :next_data_script_not_found}
    end
  end

  @doc """
  Parses Next.js JSON state into a list of normalized Property maps.
  """
  def parse_next_data(json) when is_map(json) do
    houses_map =
      get_in(json, ["props", "pageProps", "initialState", "houses"]) || %{}

    properties =
      houses_map
      |> Map.values()
      |> Enum.filter(&is_valid_house?/1)
      |> Enum.map(&normalize_house/1)

    {:ok,
     %{
       properties: properties,
       total: length(properties),
       page: 1,
       page_size: length(properties)
     }}
  end

  def parse_next_data(_), do: {:error, :invalid_json_structure}

  defp is_valid_house?(house) when is_map(house) do
    is_binary(Map.get(house, "id")) or is_integer(Map.get(house, "id"))
  end

  defp is_valid_house?(_), do: false

  @doc """
  Normalizes a raw QuintoAndar house object into a standard Property map.
  """
  def normalize_house(house) when is_map(house) do
    id = to_string(house["id"])
    url = "#{base_url()}/imovel/#{id}"
    price = extract_price(house)
    images = extract_images(house)
    location = extract_location(house)
    property_type = extract_property_type(house)
    details = extract_details(house, property_type)
    title = extract_title(house, location)

    %{
      external_id: "quintoandar-#{id}",
      title: title,
      price: price,
      url: url,
      source: "quintoandar",
      property_type: property_type,
      description: house["shortRentDescription"] || house["shortSaleDescription"] || "",
      location: location,
      details: details,
      images: images
    }
  end

  @doc """
  Extracts and normalizes the property type for QuintoAndar house items.
  """
  def extract_property_type(house) when is_map(house) do
    type = to_clean_str(house["type"])
    house_type = to_clean_str(house["houseType"])

    cond do
      matches_casa_type?(type) or matches_casa_type?(house_type) ->
        "casa"

      matches_apto_type?(type) or matches_apto_type?(house_type) ->
        "apartamento"

      matches_quarto_type?(type) or matches_quarto_type?(house_type) ->
        "quarto"

      true ->
        infer_property_type_from_text(house)
    end
  end

  def extract_property_type(_), do: "outro"

  defp matches_casa_type?(nil), do: false
  defp matches_casa_type?(""), do: false

  defp matches_casa_type?(str) when is_binary(str) do
    lower = String.downcase(str)
    String.contains?(lower, ["casa", "sobrado", "house", "townhouse", "village"])
  end

  defp matches_apto_type?(nil), do: false
  defp matches_apto_type?(""), do: false

  defp matches_apto_type?(str) when is_binary(str) do
    lower = String.downcase(str)

    String.contains?(lower, [
      "apartamento",
      "apto",
      "apartment",
      "cobertura",
      "penthouse",
      "flat",
      "loft",
      "duplex",
      "triplex"
    ])
  end

  defp matches_quarto_type?(nil), do: false
  defp matches_quarto_type?(""), do: false

  defp matches_quarto_type?(str) when is_binary(str) do
    lower = String.downcase(str)
    String.contains?(lower, ["kitnet", "studio", "quarto", "room", "kitchenette"])
  end

  defp infer_property_type_from_text(house) do
    text =
      [
        house["shortRentDescription"],
        house["shortSaleDescription"],
        house["description"]
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    cond do
      String.contains?(text, ["casa", "sobrado"]) and not String.contains?(text, "apartamento") ->
        "casa"

      String.contains?(text, ["apartamento", "apto", "cobertura", "flat", "loft"]) ->
        "apartamento"

      String.contains?(text, ["kitnet", "studio", "quarto"]) ->
        "quarto"

      true ->
        "apartamento"
    end
  end

  defp to_clean_str(nil), do: nil
  defp to_clean_str(val) when is_binary(val), do: String.trim(val)
  defp to_clean_str(atom) when is_atom(atom), do: to_string(atom)
  defp to_clean_str(_), do: nil

  defp extract_price(house) do
    case {house["forRent"], house["rentPrice"], house["salePrice"]} do
      {true, rent, _} when is_number(rent) and rent > 0 -> trunc(rent)
      {false, _, sale} when is_number(sale) and sale > 0 -> trunc(sale)
      {_, rent, _} when is_number(rent) and rent > 0 -> trunc(rent)
      {_, _, sale} when is_number(sale) and sale > 0 -> trunc(sale)
      _ -> nil
    end
  end

  defp extract_images(house) do
    photos = Map.get(house, "photos") || []

    photos_urls =
      photos
      |> Enum.map(&extract_photo_url/1)
      |> Enum.reject(&is_nil/1)

    banner_url = extract_banner_url(house["banner"])

    case {photos_urls, banner_url} do
      {[], nil} -> []
      {[], banner} -> [banner]
      {urls, _} -> urls
    end
  end

  defp extract_photo_url(%{"url" => url}) when is_binary(url) do
    format_image_url(url)
  end

  defp extract_photo_url(_), do: nil

  defp extract_banner_url(banner) when is_binary(banner) do
    format_image_url(banner)
  end

  defp extract_banner_url(_), do: nil

  defp format_image_url(url) do
    case String.starts_with?(url, "http") do
      true -> url
      false -> "#{image_base_url()}#{url}"
    end
  end

  defp image_base_url do
    "#{base_url()}/img/med/"
  end

  defp base_url do
    :kfofo
    |> Application.get_env(:quintoandar_scraper, [])
    |> Keyword.get(:base_url, System.get_env("QUINTOANDAR_BASE_URL") || "")
  end

  defp extract_location(house) do
    address = Map.get(house, "address") || %{}
    city = address["city"] || ""
    street = address["address"] || ""
    neighborhood = house["neighbourhood"] || house["regionName"] || ""

    %{
      state: nil,
      city: city,
      neighborhood: neighborhood,
      address: street,
      zipcode: ""
    }
  end

  defp extract_details(house, property_type) do
    bedrooms = parse_int_field(house["bedrooms"])
    bathrooms = parse_int_field(house["bathrooms"])
    garage_spaces = parse_int_field(house["parkingSpots"])
    area_sqm = parse_int_field(house["area"])

    %{
      property_type: property_type,
      bedrooms: bedrooms,
      rooms: bedrooms,
      bathrooms: bathrooms,
      garage_spaces: garage_spaces,
      area_sqm: area_sqm,
      area_m2: area_sqm
    }
  end

  defp parse_int_field(num) when is_integer(num), do: num
  defp parse_int_field(num) when is_float(num), do: trunc(num)

  defp parse_int_field(str) when is_binary(str) do
    case Integer.parse(str) do
      {val, _} -> val
      _ -> nil
    end
  end

  defp parse_int_field(_), do: nil

  defp extract_title(house, location) do
    case house["shortRentDescription"] do
      desc when is_binary(desc) and byte_size(desc) > 0 ->
        desc

      _ ->
        type = house["type"] || "Imóvel"
        bedrooms = house["bedrooms"]
        neighborhood = location.neighborhood

        build_fallback_title(type, bedrooms, neighborhood)
    end
  end

  defp build_fallback_title(type, bedrooms, neighborhood)
       when is_integer(bedrooms) and bedrooms > 0 and is_binary(neighborhood) and
              byte_size(neighborhood) > 0 do
    "#{type} com #{bedrooms} #{pluralize_quarto(bedrooms)} em #{neighborhood}"
  end

  defp build_fallback_title(type, _bedrooms, neighborhood)
       when is_binary(neighborhood) and byte_size(neighborhood) > 0 do
    "#{type} em #{neighborhood}"
  end

  defp build_fallback_title(type, _bedrooms, _neighborhood) do
    type
  end

  defp pluralize_quarto(1), do: "quarto"
  defp pluralize_quarto(_), do: "quartos"
end
