defmodule KfofoWeb.PropertyLiveTest do
  use KfofoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders search page correctly", %{conn: conn} do
    {:ok, view, html} = live(conn, "/properties")

    assert html =~ "Buscar Imóveis na OLX"
    assert render(view) =~ "Estado (UF)"
  end
end
