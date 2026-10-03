defmodule Kfofo.Scrapers.OlxTest do
  use ExUnit.Case, async: true

  alias Kfofo.Scrapers.Olx

  describe "build_url/1" do
    test "builds default sale imoveis URL with no options" do
      assert Olx.build_url() == "https://dummy-olx.test/imoveis/venda"
    end

    test "builds URL with state only" do
      assert Olx.build_url(%{state: "sp"}) == "https://dummy-olx.test/imoveis/venda/estado-sp"
    end

    test "builds URL with state, region and city" do
      url = Olx.build_url(%{state: "sp", region: "sao-paulo-e-regiao", city: "sao-paulo"})
      assert url == "https://dummy-olx.test/imoveis/venda/estado-sp/sao-paulo-e-regiao/sao-paulo"
    end

    test "builds rental URL with price and bedroom filters" do
      url =
        Olx.build_url(%{
          state: "rj",
          type: :aluguel,
          min_price: 1500,
          max_price: 4000,
          bedrooms: 2,
          page: 2
        })

      assert url =~ "https://dummy-olx.test/imoveis/aluguel/estado-rj?"
      assert url =~ "ps=1500"
      assert url =~ "pe=4000"
      assert url =~ "ros=2"
      assert url =~ "o=2"
    end
  end

  describe "extract_next_data/1" do
    test "successfully extracts and decodes __NEXT_DATA__ script JSON" do
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
            {"props": {"pageProps": {"totalAds": 10}}}
          </script>
        </head>
        <body></body>
      </html>
      """

      assert {:ok, %{"props" => %{"pageProps" => %{"totalAds" => 10}}}} =
               Olx.extract_next_data(html)
    end

    test "returns error if script tag is missing" do
      html = "<html><body><h1>No script</h1></body></html>"
      assert Olx.extract_next_data(html) == {:error, :next_data_script_not_found}
    end
  end

  describe "parse_next_data/1 and normalize_ad/1" do
    test "parses ads list and normalizes property fields" do
      json = %{
        "props" => %{
          "pageProps" => %{
            "totalAds" => 1,
            "page" => 1,
            "ads" => [
              %{
                "listId" => "1234567",
                "title" => "Apartamento 2 quartos no Jardins",
                "price" => "R$ 650.000",
                "url" => "https://dummy-olx.test/imoveis/anuncio-1234567",
                "description" => "Lindo apartamento reformado...",
                "date" => "2026-10-02T10:00:00Z",
                "location" => %{
                  "uf" => "SP",
                  "municipality" => "São Paulo",
                  "neighbourhood" => "Jardins",
                  "zipcode" => "01410-000"
                },
                "properties" => [
                  %{"name" => "rooms", "value" => "2"},
                  %{"name" => "bathrooms", "value" => "2"},
                  %{"name" => "garage_spaces", "value" => "1"},
                  %{"name" => "size", "value" => "75"}
                ],
                "images" => [
                  %{"original" => "https://dummy-img.test/image1.jpg"}
                ]
              }
            ]
          }
        }
      }

      assert {:ok, result} = Olx.parse_next_data(json)
      assert result.total == 1
      assert result.page == 1
      assert [property] = result.properties

      assert property.external_id == "1234567"
      assert property.title == "Apartamento 2 quartos no Jardins"
      assert property.price == 650_000
      assert property.source == "olx"
      assert property.location.city == "São Paulo"
      assert property.location.neighborhood == "Jardins"
      assert property.details.bedrooms == 2
      assert property.details.area_sqm == 75
      assert property.images == ["https://dummy-img.test/image1.jpg"]
    end
  end

  describe "fetch_properties/1" do
    test "fetches and parses properties using mock HTTP client" do
      mock_html = """
      <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
            {
              "props": {
                "pageProps": {
                  "totalAds": 1,
                  "ads": [
                    {
                      "listId": "9999",
                      "title": "Casa com piscina",
                      "price": 1200000,
                      "url": "https://dummy-olx.test/imoveis/anuncio-9999"
                    }
                  ]
                }
              }
            }
          </script>
        </head>
      </html>
      """

      mock_client = fn _url, _headers ->
        {:ok, %{status: 200, body: mock_html}}
      end

      assert {:ok, result} = Olx.fetch_properties(%{state: "sp", http_client: mock_client})
      assert result.total == 1
      assert [property] = result.properties
      assert property.external_id == "9999"
      assert property.price == 1_200_000
    end

    test "handles HTTP failure status gracefully" do
      mock_client = fn _url, _headers ->
        {:ok, %{status: 403, body: "Forbidden"}}
      end

      assert Olx.fetch_properties(%{http_client: mock_client}) == {:error, {:http_error, 403}}
    end
  end
end
