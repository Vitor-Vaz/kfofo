defmodule KfofoWeb.PropertyLiveTest do
  use KfofoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders search page at root / with Hero search and /properties with split results layout",
       %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "Kfofo"
    assert html =~ "Encontre o cantinho perfeito para chamar de"
    assert html =~ "SearchPersistence"
    refute html =~ "@elixirphoenix"
    refute html =~ "Peace of mind from prototype to production"
    assert render(view) =~ "Localização (Bairro, Cidade ou Estado)"

    {:ok, view_prop, html_prop} = live(conn, "/properties")
    assert html_prop =~ "Kfofo"
    assert render(view_prop) =~ "Filtros de Busca"
    assert render(view_prop) =~ "Resultados agregados e atualizados em tempo real"
  end

  test "triggers location suggestions via suggest_locations event", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/properties")

    render_hook(view, "suggest_locations", %{"value" => "Camp"})

    assert render(view) =~ "Kfofo"
  end

  test "select_location event updates search form location query", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/properties")

    render_hook(view, "select_location", %{
      "place-id" => "fake_place_id",
      "description" => "Bangu, Rio de Janeiro - RJ, Brasil"
    })

    assert render(view) =~ "value=\"Bangu, Rio de Janeiro - RJ, Brasil\""
  end

  test "submitting search patches URL with search parameters and emits save_search event", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/properties")

    view
    |> form("form", %{
      "search" => %{
        "location_query" => "Pinheiros, SP",
        "type" => "aluguel",
        "min_price" => "2500",
        "max_price" => "5000",
        "bedrooms" => "2"
      }
    })
    |> render_submit()

    assert_patched(
      view,
      "/properties?bedrooms=2&city=sao-paulo&location_query=Pinheiros%2C+SP&max_price=5000&min_price=2500&state=sp&type=aluguel"
    )
  end

  test "restoring search via handle_params updates form inputs", %{conn: conn} do
    {:ok, view, _html} =
      live(
        conn,
        "/properties?location_query=Copacabana&type=aluguel&bedrooms=3&city=rio-de-janeiro&state=rj"
      )

    rendered = render(view)
    assert rendered =~ "value=\"Copacabana\""
    assert rendered =~ "selected=\"selected\"" or rendered =~ "selected"
  end

  test "searching a specific neighborhood preserves selected state and city in scraper parameters",
       %{conn: conn} do
    {:ok, view, _html} =
      live(
        conn,
        "/properties?city=rio-de-janeiro&location_query=Campo+Grande%2C+Rio+de+Janeiro+-+RJ%2C+Brasil&neighborhood=campo-grande&state=rj&type=venda"
      )

    view
    |> form("form", %{
      "search" => %{
        "location_query" => "Campo Grande, Rio de Janeiro - RJ, Brasil",
        "state" => "rj",
        "city" => "rio-de-janeiro",
        "neighborhood" => "campo-grande",
        "type" => "venda"
      }
    })
    |> render_submit()

    assert_patched(
      view,
      "/properties?city=rio-de-janeiro&location_query=Campo+Grande%2C+Rio+de+Janeiro+-+RJ%2C+Brasil&neighborhood=campo-grande&state=rj&type=venda"
    )
  end
end
