defmodule KfofoWeb.PropertyLive.ShowTest do
  use KfofoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kfofo.Properties
  alias Kfofo.Properties.Store

  setup do
    Store.clear()
    :ok
  end

  @sample_property %{
    external_id: "prop-show-123",
    title: "Apartamento Luxo 3 Quartos em Ipanema",
    price: 4500,
    url: "https://www.quintoandar.com.br/imovel/123",
    source: "quintoandar",
    property_type: "apartamento",
    description: "Excelente apartamento todo reformado, sol da manhã, vista mar.",
    location: %{
      city: "Rio de Janeiro",
      neighborhood: "Ipanema",
      state: "RJ",
      address: "Rua Visconde de Pirajá"
    },
    details: %{
      bedrooms: 3,
      rooms: 3,
      bathrooms: 2,
      garage_spaces: 1,
      area_sqm: 110,
      area_m2: 110,
      condo_fee: 900,
      iptu: 350
    },
    images: [
      "https://example.com/photo1.jpg",
      "https://example.com/photo2.jpg",
      "https://example.com/photo3.jpg"
    ],
    published_at: "10 de outubro"
  }

  describe "PropertyLive.Show" do
    test "renders not found state when property does not exist in store", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/properties/unknown-id")

      assert html =~ "Imóvel não encontrado"
      assert html =~ "Este anúncio não está mais disponível no cache da busca"
      assert render(view) =~ "Buscar imóveis"
    end

    test "renders complete property details when property is present in store", %{conn: conn} do
      :ok = Properties.save_property(@sample_property)

      {:ok, view, html} = live(conn, ~p"/properties/#{@sample_property.external_id}")

      assert html =~ "Apartamento Luxo 3 Quartos em Ipanema"
      assert html =~ "R$ 4.500"
      assert html =~ "QuintoAndar"
      assert html =~ "Rua Visconde de Pirajá"
      assert html =~ "Ipanema, Rio de Janeiro - RJ"
      assert html =~ "Excelente apartamento todo reformado"
      assert html =~ "R$ 900"
      assert html =~ "R$ 350"
      assert html =~ "110 m²"
      assert html =~ "Ver anúncio oficial no QuintoAndar"
      assert render(view) =~ "Voltar para a busca"
    end

    test "preserves search filters in back link", %{conn: conn} do
      :ok = Properties.save_property(@sample_property)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/properties/#{@sample_property.external_id}?location_query=Ipanema&bedrooms=3"
        )

      assert html =~ "location_query=Ipanema"
      assert html =~ "bedrooms=3"
    end

    test "allows navigating gallery photos via next_image, prev_image and select_image", %{
      conn: conn
    } do
      :ok = Properties.save_property(@sample_property)

      {:ok, view, _html} = live(conn, ~p"/properties/#{@sample_property.external_id}")

      assert render(view) =~ "Foto 1 de 3"

      render_click(view, "next_image")
      assert render(view) =~ "Foto 2 de 3"

      render_click(view, "next_image")
      assert render(view) =~ "Foto 3 de 3"

      # Wrap around back to first
      render_click(view, "next_image")
      assert render(view) =~ "Foto 1 de 3"

      # Prev wraps to last
      render_click(view, "prev_image")
      assert render(view) =~ "Foto 3 de 3"

      # Direct selection
      render_click(view, "select_image", %{"index" => "1"})
      assert render(view) =~ "Foto 2 de 3"
    end

    test "opens and closes fullscreen photo modal", %{conn: conn} do
      :ok = Properties.save_property(@sample_property)

      {:ok, view, _html} = live(conn, ~p"/properties/#{@sample_property.external_id}")

      refute render(view) =~ "Fechar tela cheia"

      render_click(view, "open_fullscreen")
      assert render(view) =~ "Fechar tela cheia"

      render_click(view, "close_fullscreen")
      refute render(view) =~ "Fechar tela cheia"
    end

    test "copy_link event updates button state", %{conn: conn} do
      :ok = Properties.save_property(@sample_property)

      {:ok, view, _html} = live(conn, ~p"/properties/#{@sample_property.external_id}")

      assert render(view) =~ "Compartilhar este anúncio"

      render_click(view, "copy_link")
      assert render(view) =~ "Link copiado para a área de transferência!"
    end

    test "renders without error when property lacks optional keys like published_at", %{
      conn: conn
    } do
      qa_prop = %{
        external_id: "quintoandar-895647314",
        title: "Casa com 3 quartos em Campo Grande",
        price: 1300,
        url: "https://www.quintoandar.com.br/imovel/895647314",
        source: "quintoandar",
        property_type: "casa",
        description: "",
        location: %{
          address: "Rua Darcy Ribeiro",
          city: "Rio de Janeiro",
          neighborhood: "Campo Grande",
          state: nil,
          zipcode: ""
        },
        details: %{
          area_m2: 250,
          area_sqm: 250,
          bathrooms: 1,
          bedrooms: 3,
          garage_spaces: 0,
          property_type: "casa",
          rooms: 3
        },
        images: ["https://example.com/qa1.jpg"]
      }

      :ok = Properties.save_property(qa_prop)

      {:ok, view, html} = live(conn, ~p"/properties/#{qa_prop.external_id}")

      assert html =~ "Casa com 3 quartos em Campo Grande"
      assert html =~ "R$ 1.300"
      assert html =~ "Campo Grande, Rio de Janeiro"
      assert render(view) =~ "Rua Darcy Ribeiro"
    end
  end
end
