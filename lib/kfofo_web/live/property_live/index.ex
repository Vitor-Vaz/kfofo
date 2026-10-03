defmodule KfofoWeb.PropertyLive.Index do
  use KfofoWeb, :live_view

  alias Kfofo.Scrapers.Olx

  @impl true
  def mount(_params, _session, socket) do
    search_form = %{
      "state" => "sp",
      "city" => "sao-paulo",
      "type" => "venda",
      "min_price" => "",
      "max_price" => "",
      "bedrooms" => ""
    }

    socket =
      socket
      |> assign(:page_title, "Busca de Imóveis - Kfofo")
      |> assign(:search_form, search_form)
      |> assign(:loading, false)
      |> assign(:properties, [])
      |> assign(:total, 0)
      |> assign(:searched, false)
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => params}, socket) do
    socket =
      socket
      |> assign(:search_form, params)
      |> assign(:loading, true)
      |> assign(:searched, true)
      |> assign(:error_message, nil)
      |> start_async_fetch(params)

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
    %{
      state: Map.get(params, "state"),
      city: Map.get(params, "city"),
      type: parse_type(Map.get(params, "type")),
      min_price: parse_number(Map.get(params, "min_price")),
      max_price: parse_number(Map.get(params, "max_price")),
      bedrooms: parse_number(Map.get(params, "bedrooms"))
    }
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

  def first_image(images) when is_list(images) and images != [] do
    List.first(images)
  end

  def first_image(_),
    do:
      "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600&auto=format&fit=crop&q=80"
end
