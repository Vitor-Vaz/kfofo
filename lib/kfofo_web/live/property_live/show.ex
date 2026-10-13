defmodule KfofoWeb.PropertyLive.Show do
  use KfofoWeb, :live_view

  alias Kfofo.Properties

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    search_params = Map.drop(params, ["id"])

    case Properties.get_property(id) do
      {:ok, property} ->
        images = property_images(property.images)

        socket =
          socket
          |> assign(:page_title, "#{property.title} | Kfofo")
          |> assign(:property, property)
          |> assign(:images, images)
          |> assign(:active_image_index, 0)
          |> assign(:fullscreen, false)
          |> assign(:search_params, search_params)
          |> assign(:copied, false)

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> assign(:page_title, "Imóvel não encontrado | Kfofo")
          |> assign(:property, nil)
          |> assign(:images, [])
          |> assign(:active_image_index, 0)
          |> assign(:fullscreen, false)
          |> assign(:search_params, search_params)
          |> assign(:copied, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Imóvel não encontrado | Kfofo")
     |> assign(:property, nil)
     |> assign(:images, [])
     |> assign(:active_image_index, 0)
     |> assign(:fullscreen, false)
     |> assign(:search_params, %{})
     |> assign(:copied, false)}
  end

  @impl true
  def handle_event("select_image", %{"index" => index_str}, socket) do
    case Integer.parse(index_str) do
      {index, _} when index >= 0 ->
        total = length(socket.assigns.images)
        clamped_index = min(max(index, 0), max(total - 1, 0))
        {:noreply, assign(socket, :active_image_index, clamped_index)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("next_image", _params, socket) do
    total = length(socket.assigns.images)

    case total do
      0 ->
        {:noreply, socket}

      count ->
        next_index = rem(socket.assigns.active_image_index + 1, count)
        {:noreply, assign(socket, :active_image_index, next_index)}
    end
  end

  @impl true
  def handle_event("prev_image", _params, socket) do
    total = length(socket.assigns.images)

    case total do
      0 ->
        {:noreply, socket}

      count ->
        prev_index = rem(socket.assigns.active_image_index - 1 + count, count)
        {:noreply, assign(socket, :active_image_index, prev_index)}
    end
  end

  @impl true
  def handle_event("open_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, true)}
  end

  @impl true
  def handle_event("close_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, false)}
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, assign(socket, :copied, true)}
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

  def property_images(images) when is_list(images) do
    cleaned =
      images
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.map(fn
        url when is_binary(url) -> String.trim(url)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    case cleaned do
      [] -> [fallback_image()]
      list -> list
    end
  end

  def property_images(_), do: [fallback_image()]

  def fallback_image do
    "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=1200&auto=format&fit=crop&q=80"
  end

  def source_portal_name("quintoandar"), do: "QuintoAndar"
  def source_portal_name("olx"), do: "OLX"
  def source_portal_name(other) when is_binary(other), do: String.capitalize(other)
  def source_portal_name(_), do: "Portal Original"

  def source_badge_class("quintoandar"), do: "bg-blue-600 text-white"
  def source_badge_class(_), do: "bg-orange-600 text-white"

  def source_button_class("quintoandar") do
    "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 shadow-blue-600/30 text-white"
  end

  def source_button_class(_) do
    "bg-gradient-to-r from-orange-600 to-amber-600 hover:from-orange-500 hover:to-amber-500 shadow-orange-600/30 text-white"
  end

  def property_type_label("apartamento"), do: "Apartamento"
  def property_type_label("casa"), do: "Casa"
  def property_type_label("quarto"), do: "Quarto"

  def property_type_label(other) when is_binary(other) and other != "",
    do: String.capitalize(other)

  def property_type_label(_), do: "Imóvel"

  def format_location_summary(location) when is_map(location) do
    neighborhood = location[:neighborhood]
    city = location[:city]
    state = location[:state]

    case {neighborhood, city, state} do
      {n, c, s}
      when is_binary(n) and n != "" and is_binary(c) and c != "" and is_binary(s) and s != "" ->
        "#{n}, #{c} - #{s}"

      {n, c, _} when is_binary(n) and n != "" and is_binary(c) and c != "" ->
        "#{n}, #{c}"

      {_, c, s} when is_binary(c) and c != "" and is_binary(s) and s != "" ->
        "#{c} - #{s}"

      {_, c, _} when is_binary(c) and c != "" ->
        c

      {n, _, _} when is_binary(n) and n != "" ->
        n

      _ ->
        "Localização não detalhada"
    end
  end

  def format_location_summary(_), do: "Localização não detalhada"

  def return_path(search_params) when is_map(search_params) do
    clean_params =
      search_params
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    case map_size(clean_params) do
      0 -> ~p"/properties"
      _ -> ~p"/properties?#{clean_params}"
    end
  end

  def return_path(_), do: ~p"/properties"

  def active_image(images, index) when is_list(images) and images != [] do
    case Enum.at(images, index) do
      nil -> hd(images)
      url -> url
    end
  end

  def active_image(_, _), do: fallback_image()
end
