defmodule KfofoWeb.PageControllerTest do
  use KfofoWeb.ConnCase

  test "GET / loads Kfofo application", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Kfofo"
  end
end
