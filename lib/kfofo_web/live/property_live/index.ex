defmodule KfofoWeb.PropertyLive.Index do
  use KfofoWeb, :live_view

  alias Kfofo.Locations
  alias Kfofo.Scrapers

  @search_keys [
    "location_query",
    "state",
    "city",
    "neighborhood",
    "type",
    "property_type",
    "min_price",
    "max_price",
    "bedrooms",
    "garages",
    "sort_by"
  ]

  @default_search_form %{
    "location_query" => "",
    "state" => "",
    "city" => "",
    "neighborhood" => "",
    "type" => "venda",
    "property_type" => "",
    "min_price" => "",
    "max_price" => "",
    "bedrooms" => "",
    "garages" => "",
    "sort_by" => "recent"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Kfofo - O seu novo lar")
      |> assign(:search_form, @default_search_form)
      |> assign(:sort_by, "recent")
      |> assign(:location_predictions, [])
      |> assign(:show_predictions, false)
      |> assign(:location_error, nil)
      |> assign(:loading, false)
      |> assign(:raw_properties, [])
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:searched, false)
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search_params = Map.take(params, @search_keys)
    {:noreply, apply_action(socket, socket.assigns.live_action, search_params)}
  end

  defp apply_action(socket, :home, search_params) when search_params == %{} do
    socket
    |> assign(:page_title, "Kfofo - Encontre o seu novo lar")
    |> assign(:search_form, @default_search_form)
    |> assign(:sort_by, "recent")
    |> assign(:raw_properties, [])
    |> assign(:properties, [])
    |> assign(:total, 0)
    |> assign(:loading, false)
    |> assign(:searched, false)
    |> assign(:error_message, nil)
    |> assign(:show_predictions, false)
    |> push_event("clear_saved_search", %{})
  end

  defp apply_action(socket, :home, search_params) do
    query_params = clean_params(search_params)
    push_patch(socket, to: ~p"/properties?#{query_params}")
  end

  @fetch_filter_keys [
    "location_query",
    "state",
    "city",
    "neighborhood",
    "type",
    "property_type",
    "min_price",
    "max_price",
    "bedrooms",
    "garages"
  ]

  defp apply_action(socket, :results, search_params) do
    merged_form = Map.merge(@default_search_form, search_params)
    sort_by = Map.get(merged_form, "sort_by", "recent")

    prev_fetch_filters = Map.take(socket.assigns[:search_form] || %{}, @fetch_filter_keys)
    new_fetch_filters = Map.take(merged_form, @fetch_filter_keys)
    prev_sort = socket.assigns[:sort_by] || "recent"
    raw_props = socket.assigns[:raw_properties] || []

    case prev_fetch_filters == new_fetch_filters and prev_sort != sort_by and raw_props != [] do
      true ->
        sorted = sort_properties(raw_props, sort_by)

        socket
        |> assign(:page_title, "Resultados da Busca · Kfofo")
        |> assign(:search_form, merged_form)
        |> assign(:sort_by, sort_by)
        |> assign(:properties, sorted)
        |> push_event("save_search", merged_form)

      false ->
        socket
        |> assign(:page_title, "Resultados da Busca · Kfofo")
        |> assign(:search_form, merged_form)
        |> assign(:sort_by, sort_by)
        |> assign(:loading, true)
        |> assign(:searched, true)
        |> assign(:error_message, nil)
        |> assign(:show_predictions, false)
        |> push_event("save_search", merged_form)
        |> start_async_fetch(merged_form)
    end
  end

  @impl true
  def handle_event("set_type", %{"type" => type}, socket) when type in ["venda", "aluguel"] do
    updated_form = Map.put(socket.assigns.search_form, "type", type)
    {:noreply, assign(socket, :search_form, updated_form)}
  end

  @impl true
  def handle_event("quick_search", params, socket) do
    quick_query = params["query"] || ""
    quick_city = params["city"] || ""
    quick_state = params["state"] || ""
    quick_type = params["type"] || socket.assigns.search_form["type"] || "venda"

    search_data = %{
      "location_query" => quick_query,
      "city" => quick_city,
      "state" => quick_state,
      "neighborhood" => "",
      "type" => quick_type
    }

    query_params = clean_params(search_data)

    socket =
      socket
      |> push_event("save_search", search_data)
      |> push_patch(to: ~p"/properties?#{query_params}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    default_params = %{
      "location_query" => socket.assigns.search_form["location_query"] || "São Paulo, SP",
      "city" => socket.assigns.search_form["city"] || "sao-paulo",
      "state" => socket.assigns.search_form["state"] || "sp",
      "type" => "venda"
    }

    query_params = clean_params(default_params)
    {:noreply, push_patch(socket, to: ~p"/properties?#{query_params}")}
  end

  @impl true
  def handle_event("suggest_locations", %{"key" => key}, socket)
      when key in [
             "ArrowDown",
             "ArrowUp",
             "ArrowLeft",
             "ArrowRight",
             "Enter",
             "Escape",
             "Tab",
             "Shift",
             "Control",
             "Alt",
             "Meta"
           ] do
    {:noreply, socket}
  end

  @impl true
  def handle_event("suggest_locations", %{"value" => query}, socket) do
    socket =
      case String.length(String.trim(query)) do
        len when len >= 2 ->
          case Locations.search_locations(query) do
            {:ok, []} ->
              socket
              |> assign(:location_predictions, [])
              |> assign(:location_error, "Nenhum local encontrado para \"#{query}\".")
              |> assign(:show_predictions, true)

            {:ok, predictions} ->
              socket
              |> assign(:location_predictions, predictions)
              |> assign(:location_error, nil)
              |> assign(:show_predictions, true)

            {:error, {:google_places_error, "REQUEST_DENIED", msg}} ->
              socket
              |> assign(:location_predictions, [])
              |> assign(
                :location_error,
                "Google Maps: #{msg} (Verifique a GOOGLE_MAPS_API_KEY no .env)"
              )
              |> assign(:show_predictions, true)

            {:error, :missing_api_key} ->
              socket
              |> assign(:location_predictions, [])
              |> assign(:location_error, "GOOGLE_MAPS_API_KEY não configurada no arquivo .env")
              |> assign(:show_predictions, true)

            _ ->
              socket
              |> assign(:location_predictions, [])
              |> assign(:location_error, nil)
              |> assign(:show_predictions, false)
          end

        _ ->
          socket
          |> assign(:location_predictions, [])
          |> assign(:location_error, nil)
          |> assign(:show_predictions, false)
      end

    updated_form =
      socket.assigns.search_form
      |> Map.put("location_query", query)
      |> Map.put("state", "")
      |> Map.put("city", "")
      |> Map.put("neighborhood", "")

    {:noreply, assign(socket, :search_form, updated_form)}
  end

  @impl true
  def handle_event("select_location", params, socket) do
    place_id = params["place-id"] || params["place_id"]
    description = params["description"] || ""

    socket =
      case Locations.get_location_details(place_id) do
        {:ok, details} ->
          updated_form =
            socket.assigns.search_form
            |> Map.put("location_query", details.formatted_address || description)
            |> maybe_put_field("state", details.state)
            |> maybe_put_field("city", details.city)
            |> Map.put("neighborhood", details.neighborhood || "")

          socket
          |> assign(:search_form, updated_form)
          |> assign(:location_predictions, [])
          |> assign(:show_predictions, false)

        _ ->
          updated_form = Map.put(socket.assigns.search_form, "location_query", description)

          socket
          |> assign(:search_form, updated_form)
          |> assign(:location_predictions, [])
          |> assign(:show_predictions, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_predictions", _params, socket) do
    {:noreply, assign(socket, :show_predictions, false)}
  end

  @impl true
  def handle_event("search", %{"search" => params}, socket) do
    form_params = Map.take(params, @search_keys)
    merged_params = Map.merge(@default_search_form, form_params)

    merged_params =
      case merged_params["location_query"] != (socket.assigns.search_form["location_query"] || "") do
        true ->
          merged_params
          |> Map.put("state", "")
          |> Map.put("city", "")
          |> Map.put("neighborhood", "")

        false ->
          merged_params
      end

    query_params = clean_params(merged_params)
    current_query_params = clean_params(socket.assigns.search_form)

    socket =
      case query_params == current_query_params and socket.assigns.live_action == :results do
        true ->
          socket
          |> assign(:loading, true)
          |> assign(:searched, true)
          |> assign(:error_message, nil)
          |> assign(:show_predictions, false)
          |> push_event("save_search", merged_params)
          |> push_patch(to: ~p"/properties?#{query_params}")
          |> start_async_fetch(merged_params)

        false ->
          socket
          |> assign(:show_predictions, false)
          |> push_event("save_search", merged_params)
          |> push_patch(to: ~p"/properties?#{query_params}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_search", params, socket) when is_map(params) do
    form_params = Map.take(params, @search_keys)
    merged_params = Map.merge(@default_search_form, form_params)
    query_params = clean_params(merged_params)

    {:noreply, push_patch(socket, to: ~p"/properties?#{query_params}")}
  end

  @impl true
  def handle_event("change_sort", %{"sort_by" => sort_by}, socket) do
    raw = socket.assigns[:raw_properties] || socket.assigns.properties
    sorted = sort_properties(raw, sort_by)
    updated_form = Map.put(socket.assigns.search_form, "sort_by", sort_by)
    query_params = clean_params(updated_form)

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:search_form, updated_form)
      |> assign(:properties, sorted)
      |> push_patch(to: ~p"/properties?#{query_params}", replace: true)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_properties, {:ok, {:ok, result}}, socket) do
    sort_by = socket.assigns[:sort_by] || "recent"
    sorted_properties = sort_properties(result.properties, sort_by)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:raw_properties, result.properties)
      |> assign(:properties, sorted_properties)
      |> assign(:total, result.total)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_properties, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:error_message, format_error(reason))

    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_properties, {:exit, _reason}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(
        :error_message,
        "Ocorreu uma falha inesperada ao conectar com os portais de imóveis."
      )

    {:noreply, socket}
  end

  defp start_async_fetch(socket, params) do
    search_opts = parse_search_opts(params)

    start_async(socket, :fetch_properties, fn ->
      Scrapers.fetch_all_properties(search_opts)
    end)
  end

  defp parse_search_opts(params) do
    explicit_state = get_clean_string(params, "state")
    explicit_city = get_clean_string(params, "city")
    explicit_neighborhood = get_clean_string(params, "neighborhood")
    location_query = Map.get(params, "location_query") || ""

    {inferred_city, inferred_state, inferred_neighborhood} =
      parse_typed_location(location_query)

    state = explicit_state || inferred_state
    city = explicit_city || inferred_city
    neighborhood = explicit_neighborhood || inferred_neighborhood

    %{
      state: state,
      city: city,
      neighborhood: neighborhood,
      type: parse_type(Map.get(params, "type"), get_clean_string(params, "property_type")),
      property_type: get_clean_string(params, "property_type"),
      min_price: parse_number(Map.get(params, "min_price")),
      max_price: parse_number(Map.get(params, "max_price")),
      bedrooms: parse_number(Map.get(params, "bedrooms")),
      garages: parse_number(Map.get(params, "garages"))
    }
  end

  defp parse_typed_location(query) when is_binary(query) do
    trimmed =
      query
      |> String.trim()
      |> String.replace(~r/,\s*Brasil$/i, "")
      |> String.replace(~r/,\s*Brazil$/i, "")

    parts =
      trimmed
      |> String.split(~r/,\s*|\s*-\s*/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case parts do
      [neighborhood, city, uf | _] when byte_size(uf) == 2 ->
        {Locations.slugify(city), String.downcase(uf), Locations.slugify(neighborhood)}

      [city, uf] when byte_size(uf) == 2 ->
        {Locations.slugify(city), String.downcase(uf), nil}

      [single] ->
        case Regex.run(~r/^(.*?)\s+([a-zA-Z]{2})$/, single) do
          [_, city_raw, uf] when byte_size(uf) == 2 ->
            {Locations.slugify(city_raw), String.downcase(uf), nil}

          _ ->
            {nil, nil, Locations.slugify(single)}
        end

      _ ->
        {nil, nil, nil}
    end
  end

  defp parse_typed_location(_), do: {nil, nil, nil}

  defp get_clean_string(map, key) do
    case Map.get(map, key) do
      nil -> nil
      "" -> nil
      val when is_binary(val) -> String.trim(val)
      _ -> nil
    end
  end

  defp parse_type("aluguel", _), do: :aluguel
  defp parse_type(_, "quarto"), do: :aluguel
  defp parse_type(_, "quartos"), do: :aluguel
  defp parse_type(_, _), do: :venda

  defp parse_number(nil), do: nil
  defp parse_number(""), do: nil
  defp parse_number(num) when is_integer(num) and num >= 0, do: num
  defp parse_number(num) when is_integer(num), do: nil

  defp parse_number(str) when is_binary(str) do
    trimmed = String.trim(str)

    case String.starts_with?(trimmed, "-") do
      true ->
        nil

      false ->
        case Integer.parse(String.replace(trimmed, ~r/\D/, "")) do
          {num, _} when num >= 0 -> num
          _ -> nil
        end
    end
  end

  defp parse_number(_), do: nil

  defp format_error({:network_error, {:http_error, 403}}),
    do: "A OLX bloqueou a requisição (Status HTTP 403 - Forbidden). Tente novamente em instantes."

  defp format_error({:network_error, {:http_error, status}}),
    do: "A OLX respondeu com erro (Status HTTP #{status})."

  defp format_error({:http_error, status}),
    do: "Falha na requisição para a OLX (Status HTTP #{status})."

  defp format_error({:network_error, _}), do: "Erro de conexão ou timeout com a OLX."

  defp format_error(:next_data_script_not_found),
    do: "Não foi possível extrair a estrutura de dados da página da OLX."

  defp format_error(:no_ads_found),
    do: "Nenhum imóvel foi encontrado para os filtros selecionados."

  defp format_error(_), do: "Ocorreu um erro ao buscar imóveis na OLX."

  def format_price(nil), do: "Sob Consulta"

  def format_price(price) when is_number(price) do
    formatted =
      price
      |> trunc()
      |> Integer.to_charlist()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(".")
      |> String.reverse()

    "R$ #{formatted}"
  end

  def format_price(_), do: "Sob Consulta"

  def first_image([first | _]) when is_binary(first) do
    case String.trim(first) do
      "" ->
        fallback_image()

      url ->
        url
    end
  end

  def first_image(_), do: fallback_image()

  def property_images(images) when is_list(images) and images != [] do
    cleaned =
      Enum.reject(images, fn
        img when is_binary(img) -> String.trim(img) == ""
        nil -> true
        _ -> false
      end)

    case cleaned do
      [] -> [fallback_image()]
      list -> Enum.take(list, 10)
    end
  end

  def property_images(_), do: [fallback_image()]

  def source_portal_name("quintoandar"), do: "QuintoAndar"
  def source_portal_name("olx"), do: "OLX"
  def source_portal_name(other) when is_binary(other), do: String.capitalize(other)
  def source_portal_name(_), do: "Anunciante"

  def source_button_hover_class("quintoandar"), do: "hover:bg-blue-600 hover:border-blue-500"
  def source_button_hover_class(_), do: "hover:bg-orange-600 hover:border-orange-500"

  def source_badge_class("quintoandar"), do: "bg-blue-600"
  def source_badge_class(_), do: "bg-orange-600"

  def fallback_image,
    do:
      "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600&auto=format&fit=crop&q=80"

  defp maybe_put_field(map, _key, nil), do: map
  defp maybe_put_field(map, _key, ""), do: map
  defp maybe_put_field(map, key, val), do: Map.put(map, key, val)

  defp sort_properties(properties, "price_asc") when is_list(properties) do
    Enum.sort_by(
      properties,
      fn prop ->
        case prop.price do
          price when is_number(price) -> price
          _ -> :infinity
        end
      end,
      :asc
    )
  end

  defp sort_properties(properties, "price_desc") when is_list(properties) do
    Enum.sort_by(
      properties,
      fn prop ->
        case prop.price do
          price when is_number(price) -> price
          _ -> -1
        end
      end,
      :desc
    )
  end

  defp sort_properties(properties, _), do: properties

  defp clean_params(params) do
    params
    |> Enum.reject(fn
      {_k, v} when is_nil(v) or v == "" -> true
      {"sort_by", "recent"} -> true
      _ -> false
    end)
    |> Map.new()
  end
end
