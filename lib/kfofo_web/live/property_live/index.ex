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
    "source",
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
    "source" => "",
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
      |> assign(:portal_status, %{olx: :idle, quintoandar: :idle})
      |> assign(:portal_counts, %{olx: 0, quintoandar: 0})
      |> assign(:portal_errors, %{olx: nil, quintoandar: nil})
      |> assign(:portal_results, %{olx: [], quintoandar: []})

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
    |> assign(:portal_status, %{olx: :idle, quintoandar: :idle})
    |> assign(:portal_counts, %{olx: 0, quintoandar: 0})
    |> assign(:portal_errors, %{olx: nil, quintoandar: nil})
    |> assign(:portal_results, %{olx: [], quintoandar: []})
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
    "source",
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
  def handle_event("set_source", %{"source" => source}, socket) do
    updated_form = Map.put(socket.assigns.search_form, "source", source)
    query_params = clean_params(updated_form)
    {:noreply, push_patch(socket, to: ~p"/properties?#{query_params}")}
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
  def handle_async({:fetch_portal, portal}, {:ok, {:ok, result}}, socket) do
    new_results = Map.put(socket.assigns.portal_results, portal, result.properties)
    new_counts = Map.put(socket.assigns.portal_counts, portal, length(result.properties))
    new_status = Map.put(socket.assigns.portal_status, portal, :done)
    new_errors = Map.put(socket.assigns.portal_errors, portal, nil)

    is_still_loading = Enum.any?(new_status, fn {_k, status} -> status == :loading end)

    combined_raw =
      [new_results.olx, new_results.quintoandar]
      |> Scrapers.interleave_or_dedup()

    sort_by = socket.assigns[:sort_by] || "recent"
    sorted = sort_properties(combined_raw, sort_by)

    socket =
      socket
      |> assign(:portal_status, new_status)
      |> assign(:portal_counts, new_counts)
      |> assign(:portal_errors, new_errors)
      |> assign(:portal_results, new_results)
      |> assign(:loading, is_still_loading)
      |> assign(:raw_properties, combined_raw)
      |> assign(:properties, sorted)
      |> assign(:total, length(combined_raw))

    {:noreply, socket}
  end

  @impl true
  def handle_async({:fetch_portal, portal}, {:ok, {:error, reason}}, socket) do
    error_text = format_portal_error(portal, reason)
    new_status = Map.put(socket.assigns.portal_status, portal, :error)
    new_errors = Map.put(socket.assigns.portal_errors, portal, error_text)

    is_still_loading = Enum.any?(new_status, fn {_k, status} -> status == :loading end)

    all_failed =
      Enum.all?(new_status, fn {_k, status} -> status in [:error, :skipped] end) and
        socket.assigns.properties == []

    general_error =
      case all_failed do
        true -> "Não foi possível carregar os imóveis dos portais parceiros no momento."
        false -> socket.assigns.error_message
      end

    socket =
      socket
      |> assign(:portal_status, new_status)
      |> assign(:portal_errors, new_errors)
      |> assign(:loading, is_still_loading)
      |> assign(:error_message, general_error)

    {:noreply, socket}
  end

  @impl true
  def handle_async({:fetch_portal, portal}, {:exit, _reason}, socket) do
    error_text =
      "Falha inesperada ao comunicar com o portal #{source_portal_name(to_string(portal))}."

    new_status = Map.put(socket.assigns.portal_status, portal, :error)
    new_errors = Map.put(socket.assigns.portal_errors, portal, error_text)

    is_still_loading = Enum.any?(new_status, fn {_k, status} -> status == :loading end)

    socket =
      socket
      |> assign(:portal_status, new_status)
      |> assign(:portal_errors, new_errors)
      |> assign(:loading, is_still_loading)

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
    source_opt = search_opts[:source]

    initial_status = %{
      olx: portal_initial_status(:olx, source_opt),
      quintoandar: portal_initial_status(:quintoandar, source_opt)
    }

    socket
    |> assign(:loading, true)
    |> assign(:portal_status, initial_status)
    |> assign(:portal_counts, %{olx: 0, quintoandar: 0})
    |> assign(:portal_errors, %{olx: nil, quintoandar: nil})
    |> assign(:portal_results, %{olx: [], quintoandar: []})
    |> assign(:raw_properties, [])
    |> assign(:properties, [])
    |> assign(:total, 0)
    |> maybe_start_portal_fetch(:olx, search_opts, source_opt)
    |> maybe_start_portal_fetch(:quintoandar, search_opts, source_opt)
  end

  defp portal_initial_status(portal, source_opt) do
    case source_opt do
      nil ->
        :loading

      "all" ->
        :loading

      "" ->
        :loading

      source when is_binary(source) ->
        case to_string(portal) == source do
          true -> :loading
          false -> :skipped
        end

      _ ->
        :loading
    end
  end

  defp maybe_start_portal_fetch(socket, portal, search_opts, source_opt) do
    case portal_initial_status(portal, source_opt) do
      :loading ->
        start_async(socket, {:fetch_portal, portal}, fn ->
          Scrapers.fetch_portal(portal, search_opts)
        end)

      :skipped ->
        socket
    end
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
      source: get_clean_string(params, "source"),
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
    do:
      "Os portais bloquearam a requisição temporariamente (Status HTTP 403). Tente novamente em instantes."

  defp format_error({:http_error, 403}),
    do:
      "Os portais bloquearam a requisição temporariamente (Status HTTP 403). Tente novamente em instantes."

  defp format_error({:network_error, {:http_error, status}}),
    do: "Os portais responderam com erro (Status HTTP #{status})."

  defp format_error({:http_error, status}),
    do: "Falha na requisição para os portais (Status HTTP #{status})."

  defp format_error(:timeout),
    do: "A busca demorou mais que o esperado para responder. Tente novamente em instantes."

  defp format_error({:network_error, _}),
    do: "Erro de conexão ou timeout com os portais parceiros."

  defp format_error(:next_data_script_not_found),
    do: "Não foi possível extrair a estrutura de dados dos portais."

  defp format_error(:no_ads_found),
    do: "Nenhum imóvel foi encontrado para os filtros selecionados."

  defp format_error(_), do: "Ocorreu um erro ao buscar imóveis nos portais parceiros."

  defp format_portal_error(portal, {:network_error, {:http_error, 403}}) do
    "O portal #{source_portal_name(to_string(portal))} bloqueou a requisição temporariamente (HTTP 403)."
  end

  defp format_portal_error(portal, {:http_error, 403}) do
    "O portal #{source_portal_name(to_string(portal))} bloqueou a requisição temporariamente (HTTP 403)."
  end

  defp format_portal_error(portal, :timeout) do
    "Tempo limite de resposta excedido para #{source_portal_name(to_string(portal))}."
  end

  defp format_portal_error(portal, {:network_error, _}) do
    "Falha de conexão com #{source_portal_name(to_string(portal))}."
  end

  defp format_portal_error(portal, :no_ads_found) do
    "Nenhum anúncio retornado pela #{source_portal_name(to_string(portal))} para esta busca."
  end

  defp format_portal_error(portal, _reason) do
    "Não foi possível obter anúncios de #{source_portal_name(to_string(portal))}."
  end

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
      {"source", "all"} -> true
      _ -> false
    end)
    |> Map.new()
  end

  @doc """
  Renders a loading/status card component for OLX.
  """
  attr :status, :atom, required: true
  attr :count, :integer, default: 0
  attr :error, :string, default: nil

  def olx_loading_card(assigns) do
    ~H"""
    <div class={"relative overflow-hidden rounded-2xl border transition-all duration-300 p-4 #{olx_card_classes(@status)}"}>
      <!-- Background Ambient Glow -->
      <div class="pointer-events-none absolute -top-8 -right-8 w-24 h-24 rounded-full bg-orange-500/10 blur-2xl">
      </div>

      <div class="flex items-center justify-between gap-3 relative z-10">
        <div class="flex items-center gap-3">
          <!-- OLX Logo Badge -->
          <div class="flex items-center justify-center h-9 px-3 rounded-xl bg-gradient-to-tr from-orange-600 via-orange-500 to-amber-500 text-white font-black text-xs tracking-wider shadow-md shadow-orange-600/30">
            OLX
          </div>
          <div>
            <div class="flex items-center gap-2">
              <span class="text-sm font-bold text-white tracking-tight">OLX Imóveis</span>
              <span class="text-[10px] text-zinc-400 font-medium">Parceiro</span>
            </div>
            <p class="text-[11px] text-zinc-400">
              <%= case @status do %>
                <% :loading -> %>
                  Sincronizando anúncios em tempo real...
                <% :done -> %>
                  Busca finalizada com sucesso
                <% :error -> %>
                  Portal indisponível no momento
                <% :skipped -> %>
                  Busca desativada pelo filtro
                <% _ -> %>
                  Aguardando consulta
              <% end %>
            </p>
          </div>
        </div>
        
    <!-- Status Pill -->
        <div>
          <%= case @status do %>
            <% :loading -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-orange-500/15 border border-orange-500/40 text-orange-400 shadow-inner">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
                </span>
                <span>Buscando...</span>
              </div>
            <% :done -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-500/15 border border-emerald-500/30 text-emerald-400">
                <span class="text-xs">✓</span>
                <span>{@count} {if @count == 1, do: "imóvel", else: "imóveis"}</span>
              </div>
            <% :error -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-amber-500/15 border border-amber-500/30 text-amber-400">
                <span>⚠️</span>
                <span>Indisponível</span>
              </div>
            <% :skipped -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-zinc-800 text-zinc-400 border border-zinc-700/50">
                <span>Filtro inativo</span>
              </div>
            <% _ -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-zinc-800 text-zinc-400">
                <span>Pronto</span>
              </div>
          <% end %>
        </div>
      </div>
      
    <!-- Animated Progress Bar / Status Detail -->
      <div class="mt-3 relative z-10">
        <%= case @status do %>
          <% :loading -> %>
            <div class="w-full bg-zinc-800/80 rounded-full h-1.5 overflow-hidden">
              <div class="h-1.5 rounded-full bg-gradient-to-r from-orange-500 via-amber-400 to-orange-600 animate-[pulse_1.2s_ease-in-out_infinite] w-3/4">
              </div>
            </div>
            <div class="mt-2 flex items-center justify-between text-[11px] text-zinc-400">
              <span class="flex items-center gap-1.5">
                <span class="animate-spin text-orange-400 inline-block text-xs">⟳</span>
                Aguardando resposta do portal OLX...
              </span>
              <span class="text-orange-400/80 font-mono text-[10px]">Rotacionando</span>
            </div>
          <% :done -> %>
            <div class="w-full bg-zinc-800/80 rounded-full h-1.5 overflow-hidden">
              <div class="h-1.5 rounded-full bg-emerald-500 w-full transition-all duration-500"></div>
            </div>
            <div class="mt-2 flex items-center justify-between text-[11px] text-zinc-300">
              <span class="text-zinc-400">Anúncios integrados ao feed</span>
              <span class="text-emerald-400 font-semibold text-[11px]">100% concluído</span>
            </div>
          <% :error -> %>
            <div class="rounded-xl bg-amber-950/30 border border-amber-800/40 p-2.5 text-xs text-amber-300 flex items-start gap-2">
              <span class="text-sm">⚠️</span>
              <span class="text-[11px] leading-snug">
                {@error || "Não foi possível sincronizar os imóveis da OLX no momento."}
              </span>
            </div>
          <% _ -> %>
            <div class="text-[11px] text-zinc-500">Pronto para buscar</div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading/status card component for QuintoAndar.
  """
  attr :status, :atom, required: true
  attr :count, :integer, default: 0
  attr :error, :string, default: nil

  def quintoandar_loading_card(assigns) do
    ~H"""
    <div class={"relative overflow-hidden rounded-2xl border transition-all duration-300 p-4 #{quintoandar_card_classes(@status)}"}>
      <!-- Background Ambient Glow -->
      <div class="pointer-events-none absolute -top-8 -right-8 w-24 h-24 rounded-full bg-blue-500/10 blur-2xl">
      </div>

      <div class="flex items-center justify-between gap-3 relative z-10">
        <div class="flex items-center gap-3">
          <!-- QuintoAndar Logo Badge -->
          <div class="flex items-center justify-center h-9 px-3 rounded-xl bg-gradient-to-tr from-blue-700 via-blue-600 to-indigo-500 text-white font-black text-xs tracking-wider shadow-md shadow-blue-600/30">
            5A
          </div>
          <div>
            <div class="flex items-center gap-2">
              <span class="text-sm font-bold text-white tracking-tight">QuintoAndar</span>
              <span class="text-[10px] text-zinc-400 font-medium">Parceiro</span>
            </div>
            <p class="text-[11px] text-zinc-400">
              <%= case @status do %>
                <% :loading -> %>
                  Sincronizando anúncios em tempo real...
                <% :done -> %>
                  Busca finalizada com sucesso
                <% :error -> %>
                  Portal indisponível no momento
                <% :skipped -> %>
                  Busca desativada pelo filtro
                <% _ -> %>
                  Aguardando consulta
              <% end %>
            </p>
          </div>
        </div>
        
    <!-- Status Pill -->
        <div>
          <%= case @status do %>
            <% :loading -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-blue-500/15 border border-blue-500/40 text-blue-400 shadow-inner">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-blue-500"></span>
                </span>
                <span>Buscando...</span>
              </div>
            <% :done -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-500/15 border border-emerald-500/30 text-emerald-400">
                <span class="text-xs">✓</span>
                <span>{@count} {if @count == 1, do: "imóvel", else: "imóveis"}</span>
              </div>
            <% :error -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-amber-500/15 border border-amber-500/30 text-amber-400">
                <span>⚠️</span>
                <span>Indisponível</span>
              </div>
            <% :skipped -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-zinc-800 text-zinc-400 border border-zinc-700/50">
                <span>Filtro inativo</span>
              </div>
            <% _ -> %>
              <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-zinc-800 text-zinc-400">
                <span>Pronto</span>
              </div>
          <% end %>
        </div>
      </div>
      
    <!-- Animated Progress Bar / Status Detail -->
      <div class="mt-3 relative z-10">
        <%= case @status do %>
          <% :loading -> %>
            <div class="w-full bg-zinc-800/80 rounded-full h-1.5 overflow-hidden">
              <div class="h-1.5 rounded-full bg-gradient-to-r from-blue-500 via-indigo-400 to-blue-600 animate-[pulse_1.2s_ease-in-out_infinite] w-3/4">
              </div>
            </div>
            <div class="mt-2 flex items-center justify-between text-[11px] text-zinc-400">
              <span class="flex items-center gap-1.5">
                <span class="animate-spin text-blue-400 inline-block text-xs">⟳</span>
                Aguardando resposta da API QuintoAndar...
              </span>
              <span class="text-blue-400/80 font-mono text-[10px]">Conectando</span>
            </div>
          <% :done -> %>
            <div class="w-full bg-zinc-800/80 rounded-full h-1.5 overflow-hidden">
              <div class="h-1.5 rounded-full bg-emerald-500 w-full transition-all duration-500"></div>
            </div>
            <div class="mt-2 flex items-center justify-between text-[11px] text-zinc-300">
              <span class="text-zinc-400">Anúncios integrados ao feed</span>
              <span class="text-emerald-400 font-semibold text-[11px]">100% concluído</span>
            </div>
          <% :error -> %>
            <div class="rounded-xl bg-amber-950/30 border border-amber-800/40 p-2.5 text-xs text-amber-300 flex items-start gap-2">
              <span class="text-sm">⚠️</span>
              <span class="text-[11px] leading-snug">
                {@error || "Não foi possível sincronizar os imóveis do QuintoAndar no momento."}
              </span>
            </div>
          <% _ -> %>
            <div class="text-[11px] text-zinc-500">Pronto para buscar</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp olx_card_classes(:loading),
    do: "bg-zinc-900/90 border-orange-500/40 shadow-lg shadow-orange-950/20"

  defp olx_card_classes(:done),
    do: "bg-zinc-900/80 border-zinc-800/90 shadow-md"

  defp olx_card_classes(:error),
    do: "bg-zinc-900/80 border-amber-500/30"

  defp olx_card_classes(:skipped),
    do: "bg-zinc-900/40 border-zinc-800/40 opacity-50"

  defp olx_card_classes(_),
    do: "bg-zinc-900/60 border-zinc-800"

  defp quintoandar_card_classes(:loading),
    do: "bg-zinc-900/90 border-blue-500/40 shadow-lg shadow-blue-950/20"

  defp quintoandar_card_classes(:done),
    do: "bg-zinc-900/80 border-zinc-800/90 shadow-md"

  defp quintoandar_card_classes(:error),
    do: "bg-zinc-900/80 border-amber-500/30"

  defp quintoandar_card_classes(:skipped),
    do: "bg-zinc-900/40 border-zinc-800/40 opacity-50"

  defp quintoandar_card_classes(_),
    do: "bg-zinc-900/60 border-zinc-800"
end
