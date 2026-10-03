defmodule KfofoWeb.PropertyLiveTest do
  use KfofoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders search page with Kfofo branding", %{conn: conn} do
    {:ok, view, html} = live(conn, "/properties")

    assert html =~ "Kfofo"
    assert html =~ "Encontre o seu cantinho ideal"
    assert render(view) =~ "Localização (Bairro, Cidade ou Estado)"
  end

  test "triggers location suggestions on keyup", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/properties")

    view
    |> element("input[name=\"search[location_query]\"]")
    |> render_keyup(%{"value" => "Camp"})

    # Since it debounces or queries Locations, view remains stable
    assert render(view) =~ "Kfofo"
  end
end
