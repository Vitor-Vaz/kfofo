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
    |> form("form[phx-submit='search']", %{
      "search" => %{
        "location_query" => "Pinheiros, SP",
        "type" => "aluguel",
        "property_type" => "apartamento",
        "min_price" => "1000",
        "max_price" => "2500",
        "bedrooms" => "2",
        "garages" => "1"
      }
    })
    |> render_submit()

    assert_patched(
      view,
      "/properties?bedrooms=2&garages=1&location_query=Pinheiros%2C+SP&max_price=2500&min_price=1000&property_type=apartamento&type=aluguel"
    )
  end

  test "returning to home page / clears filters and resets search form", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/properties?location_query=Copacabana&type=aluguel&min_price=1000")

    render_patch(view, ~p"/")

    assert render(view) =~ "Encontre o cantinho perfeito"
    refute render(view) =~ "value=\"Copacabana\""
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
    |> form("form[phx-submit='search']", %{
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

  test "gracefully handles negative numbers in search params without errors", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/properties?min_price=-500&max_price=-1000&bedrooms=-2&type=venda")

    assert render(view) =~ "Kfofo"
  end

  test "changing sort order triggers change_sort event and patches URL", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/properties?location_query=Copacabana&type=aluguel")

    view
    |> element("form[phx-change='change_sort']")
    |> render_change(%{"sort_by" => "price_asc"})

    assert_patched(view, "/properties?location_query=Copacabana&sort_by=price_asc&type=aluguel")
  end

  test "supports price_desc and recent sort options", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/properties?location_query=Copacabana&type=aluguel&sort_by=price_desc")

    assert render(view) =~ "Maior valor"
  end

  test "clicking source quick filter tabs patches URL with source parameter", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/properties?location_query=Moema&type=aluguel")

    view
    |> element("button[phx-value-source='quintoandar']")
    |> render_click()

    assert_patched(
      view,
      "/properties?location_query=Moema&source=quintoandar&type=aluguel"
    )

    view
    |> element("button[phx-value-source='olx']")
    |> render_click()

    assert_patched(
      view,
      "/properties?location_query=Moema&source=olx&type=aluguel"
    )
  end

  test "submitting sidebar search preserves existing source filter parameter", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/properties?source=quintoandar&location_query=Vila+Mariana")

    view
    |> form("form[phx-submit='search']", %{
      "search" => %{
        "location_query" => "Vila Mariana, SP",
        "type" => "venda"
      }
    })
    |> render_submit()

    assert_patched(
      view,
      "/properties?location_query=Vila+Mariana%2C+SP&source=quintoandar&type=venda"
    )
  end
end
