defmodule KfofoWeb.PropertyLive.Index do
  use KfofoWeb, :live_view

  alias Kfofo.Locations
  alias Kfofo.Scrapers.Olx

  @impl true
  def mount(_params, _session, socket) do
    search_form = %{
      "location_query" => "São Paulo, SP",
      "state" => "sp",
      "city" => "sao-paulo",
      "neighborhood" => "",
      "type" => "venda",
      "min_price" => "",
      "max_price" => "",
      "bedrooms" => ""
    }

    socket =
      socket
      |> assign(:page_title, "Kfofo - O seu novo lar")
      |> assign(:search_form, search_form)
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
  def handle_event(
        "select_location",
        %{"place-id" => place_id, "description" => description},
        socket
      ) do
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

    socket =
      socket
      |> assign(:search_form, merged_params)
      |> assign(:loading, true)
      |> assign(:searched, true)
      |> assign(:error_message, nil)
      |> assign(:show_predictions, false)
      |> start_async_fetch(merged_params)

    {:noreply, socket}
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
    location_query = Map.get(params, "location_query") || ""
    {inferred_city, inferred_state, inferred_neighborhood} = parse_typed_location(location_query)

    state = choose_location_val(inferred_state, Map.get(params, "state"))
    city = choose_location_val(inferred_city, Map.get(params, "city"))
    neighborhood = choose_location_val(Map.get(params, "neighborhood"), inferred_neighborhood)

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
    trimmed = String.trim(query)

    parts =
      trimmed
      |> String.split(~r/,\s*|\s*-\s*/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case parts do
      [neighborhood, city, uf] when byte_size(uf) == 2 ->
        {Locations.slugify(city), String.downcase(uf), Locations.slugify(neighborhood)}

      [city, uf] when byte_size(uf) == 2 ->
        {Locations.slugify(city), String.downcase(uf), nil}

      [single] ->
        case Regex.run(~r/^(.*?)\s+([a-zA-Z]{2})$/, single) do
          [_, city_raw, uf] ->
            {Locations.slugify(city_raw), String.downcase(uf), nil}

          _ ->
            {Locations.slugify(single), nil, nil}
        end

      _ ->
        {nil, nil, nil}
    end
  end

  defp parse_typed_location(_), do: {nil, nil, nil}

  defp choose_location_val(nil, fallback), do: fallback
  defp choose_location_val("", fallback), do: fallback
  defp choose_location_val(val, _fallback), do: val

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

  def first_image(images) when is_list(images) and images != [] do
    List.first(images)
  end

  def first_image(_),
    do:
      "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600&auto=format&fit=crop&q=80"

  defp maybe_put_field(map, _key, nil), do: map
  defp maybe_put_field(map, _key, ""), do: map
  defp maybe_put_field(map, key, val), do: Map.put(map, key, val)
end
