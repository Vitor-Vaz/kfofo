defmodule KfofoWeb.PropertyLive.Index do
  use KfofoWeb, :live_view

  alias Kfofo.Locations
  alias Kfofo.Scrapers.Olx

  @search_keys [
    "location_query",
    "state",
    "city",
    "neighborhood",
    "type",
    "min_price",
    "max_price",
    "bedrooms"
  ]

  @default_search_form %{
    "location_query" => "São Paulo, SP",
    "state" => "sp",
    "city" => "sao-paulo",
    "neighborhood" => "",
    "type" => "venda",
    "min_price" => "",
    "max_price" => "",
    "bedrooms" => ""
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Kfofo - O seu novo lar")
      |> assign(:search_form, @default_search_form)
      |> assign(:location_predictions, [])
      |> assign(:show_predictions, false)
      |> assign(:location_error, nil)
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:searched, false)
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search_params = Map.take(params, @search_keys)

    case map_size(search_params) > 0 do
      true ->
        merged_form = Map.merge(socket.assigns.search_form, search_params)

        socket =
          socket
          |> assign(:search_form, merged_form)
          |> assign(:loading, true)
          |> assign(:searched, true)
          |> assign(:error_message, nil)
          |> assign(:show_predictions, false)
          |> push_event("save_search", merged_form)
          |> start_async_fetch(merged_form)

        {:noreply, socket}

      false ->
        {:noreply, socket}
    end
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

    updated_form = Map.put(socket.assigns.search_form, "location_query", query)
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
    merged_params = Map.merge(socket.assigns.search_form, params)
    query_params = clean_params(merged_params)

    socket =
      socket
      |> push_event("save_search", merged_params)
      |> push_patch(to: ~p"/properties?#{query_params}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_search", params, socket) when is_map(params) do
    merged_params = Map.merge(socket.assigns.search_form, Map.take(params, @search_keys))
    query_params = clean_params(merged_params)

    {:noreply, push_patch(socket, to: ~p"/properties?#{query_params}")}
  end

  @impl true
  def handle_async(:fetch_olx, {:ok, {:ok, result}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:properties, result.properties)
      |> assign(:total, result.total)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_olx, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:error_message, format_error(reason))

    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_olx, {:exit, _reason}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:error_message, "Ocorreu uma falha inesperada ao conectar com a OLX.")

    {:noreply, socket}
  end

  defp start_async_fetch(socket, params) do
    search_opts = parse_search_opts(params)

    start_async(socket, :fetch_olx, fn ->
      Olx.fetch_properties(search_opts)
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
      type: parse_type(Map.get(params, "type")),
      min_price: parse_number(Map.get(params, "min_price")),
      max_price: parse_number(Map.get(params, "max_price")),
      bedrooms: parse_number(Map.get(params, "bedrooms"))
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

  defp parse_type("aluguel"), do: :aluguel
  defp parse_type(_), do: :venda

  defp parse_number(nil), do: nil

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(String.replace(str, ~r/\D/, "")) do
      {num, _} -> num
      :error -> nil
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

  def fallback_image,
    do:
      "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600&auto=format&fit=crop&q=80"

  defp maybe_put_field(map, _key, nil), do: map
  defp maybe_put_field(map, _key, ""), do: map
  defp maybe_put_field(map, key, val), do: Map.put(map, key, val)

  defp clean_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
end
