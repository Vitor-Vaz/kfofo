defmodule Kfofo.Scrapers.Olx.Parser do
  @moduledoc """
  Parser module for OLX HTML and JSON payloads.
  Converts raw DOM/JSON into normalized property data structures.
  """

  @doc """
  Attempts to parse properties from HTML cards first, falling back to JSON script tag.
  """
  def parse_page(html) when is_binary(html) do
    case parse_html_cards(html) do
      {:ok, result} ->
        {:ok, result}

      {:error, _} ->
        with {:ok, json} <- extract_next_data(html),
             {:ok, result} <- parse_next_data(json) do
          {:ok, result}
        end
    end
  end

  @doc """
  Parses HTML document containing `.olx-adcard` sections.
  """
  def parse_html_cards(html) when is_binary(html) do
    images_map = extract_rsc_images_map(html)

    with {:ok, doc} <- Floki.parse_document(html),
         cards when cards != [] <- Floki.find(doc, "section.olx-adcard") do
      properties = Enum.map(cards, &normalize_card(&1, images_map))

      {:ok,
       %{
         properties: properties,
         total: length(properties),
         page: 1,
         page_size: length(properties)
       }}
    else
      [] -> {:error, :no_cards_found}
      {:error, reason} -> {:error, {:parse_error, reason}}
      _ -> {:error, :no_cards_found}
    end
  end

  @doc """
  Normalizes a single `.olx-adcard` HTML node into a standard Property map.
  """
  def normalize_card(card, images_map \\ %{}) do
    link =
      card
      |> Floki.find("a[data-testid=\"adcard-link\"]")
      |> Floki.attribute("href")
      |> List.first()
      |> Kernel.||("")

    title =
      card
      |> Floki.find(".olx-adcard__title")
      |> Floki.text()
      |> String.trim()

    price_raw =
      card
      |> Floki.find(".olx-adcard__price")
      |> Floki.text()
      |> String.trim()

    location_raw =
      card
      |> Floki.find(".olx-adcard__location")
      |> Floki.text()
      |> String.trim()

    image = extract_card_thumbnail(card)

    date =
      card
      |> Floki.find(".olx-adcard__date")
      |> Floki.text()
      |> String.trim()

    external_id = extract_id_from_url(link)
    images = resolve_card_images(images_map, external_id, image)

    parsed_location = parse_location_string(location_raw)
    state_from_url = extract_state_from_url(link)
    final_location = Map.put(parsed_location, :state, parsed_location[:state] || state_from_url)

    %{
      external_id: external_id,
      title: title,
      price: parse_price(price_raw),
      url: link,
      source: "olx",
      description: "",
      location: final_location,
      details: parse_card_details(card),
      images: images,
      published_at: date
    }
  end

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

  defp parse_location_string(str) when is_binary(str) do
    case str |> String.split(",") |> Enum.map(&String.trim/1) do
      [city, neighborhood | _] ->
        %{city: city, neighborhood: neighborhood, state: nil, zipcode: nil}

      [city] ->
        %{city: city, neighborhood: nil, state: nil, zipcode: nil}

      _ ->
        %{city: nil, neighborhood: nil, state: nil, zipcode: nil}
    end
  end

  defp parse_card_details(card) do
    card
    |> Floki.find(".olx-adcard__detail")
    |> Enum.reduce(%{area_sqm: nil, bedrooms: nil, bathrooms: nil, garage_spaces: nil}, fn node,
                                                                                           acc ->
      aria = Floki.attribute(node, "aria-label") |> List.first() |> Kernel.||("")
      text = Floki.text(node) |> String.trim()
      num = parse_int(text)

      assign_detail(acc, aria, num)
    end)
  end

  defp assign_detail(acc, aria, num) do
    cond do
      String.contains?(aria, "metros quadrados") -> %{acc | area_sqm: num}
      String.contains?(aria, "quarto") -> %{acc | bedrooms: num}
      String.contains?(aria, "banheiro") -> %{acc | bathrooms: num}
      String.contains?(aria, "vaga") -> %{acc | garage_spaces: num}
      true -> acc
    end
  end

  defp extract_card_thumbnail(card) do
    card
    |> Floki.find("picture img, img.olx-adcard__image, img")
    |> extract_image_attributes()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> List.first()
  end

  defp extract_image_attributes(nodes) do
    Floki.attribute(nodes, "src") ++
      Floki.attribute(nodes, "data-src") ++
      Floki.attribute(nodes, "data-srcset")
  end

  defp resolve_card_images(images_map, external_id, fallback_image) do
    case Map.get(images_map, external_id) do
      imgs when is_list(imgs) and imgs != [] -> imgs
      _ -> extract_card_images(fallback_image)
    end
  end

  defp extract_card_images(nil), do: []

  defp extract_card_images(url) when is_binary(url) do
    case String.trim(url) do
      "" -> []
      trimmed -> [trimmed]
    end
  end

  defp extract_id_from_url(url) when is_binary(url) do
    case Regex.run(~r/-(\d{7,})$/, url) do
      [_, id] -> id
      _ -> ""
    end
  end

  defp extract_id_from_url(_), do: ""

  @doc """
  Extracts the Brazilian 2-letter state acronym from an OLX ad URL subdomain or path.
  """
  def extract_state_from_url(url) when is_binary(url) do
    case Regex.run(~r/^https?:\/\/([a-z]{2})\.olx\.com\.br/i, url) do
      [_, state_code] ->
        String.downcase(state_code)

      _ ->
        case Regex.run(~r/\/estado-([a-z]{2})/i, url) do
          [_, state_code] -> String.downcase(state_code)
          _ -> nil
        end
    end
  end

  def extract_state_from_url(_), do: nil

  @doc """
  Extracts mapping of ad external IDs to list of images from RSC scripts if present.
  """
  def extract_rsc_images_map(html) when is_binary(html) do
    with {:ok, doc} <- Floki.parse_document(html),
         scripts <- Floki.find(doc, "script"),
         matching when not is_nil(matching) <- find_list_id_script(scripts),
         {:ok, text} <- get_script_text_content(matching),
         {:ok, unescaped} <- extract_and_unescape_rsc(text) do
      parse_rsc_images(unescaped)
    else
      _ -> %{}
    end
  end

  defp find_list_id_script(scripts) do
    Enum.find(scripts, fn {"script", _attrs, children} ->
      case children do
        [t] when is_binary(t) -> String.contains?(t, "listId")
        _ -> false
      end
    end)
  end

  defp get_script_text_content({"script", _attrs, [text]}) when is_binary(text), do: {:ok, text}
  defp get_script_text_content(_), do: :error

  defp extract_and_unescape_rsc(text) do
    case Regex.run(~r/self\.__next_f\.push\(\[1,\s*\"(.*)\"\]\)\s*$/s, text) do
      [_, inner_escaped] -> Jason.decode("\"" <> inner_escaped <> "\"")
      _ -> :error
    end
  end

  defp parse_rsc_images(unescaped) do
    regex = ~r/\"listId\":(\d+)[^\[]*?\"images\":(\[[^\]]+\])/

    Regex.scan(regex, unescaped)
    |> Enum.reduce(%{}, fn [_, id, images_json], acc ->
      case Jason.decode(images_json) do
        {:ok, imgs} ->
          urls =
            imgs
            |> Enum.map(fn img -> img["originalWebp"] || img["original"] end)
            |> Enum.reject(&is_nil/1)

          Map.put(acc, id, urls)

        _ ->
          acc
      end
    end)
  end
end
