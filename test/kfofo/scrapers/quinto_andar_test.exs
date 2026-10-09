defmodule Kfofo.Scrapers.QuintoAndarTest do
  use ExUnit.Case, async: true

  alias Kfofo.Scrapers.QuintoAndar

  describe "build_url/1" do
    test "builds default rent URL with no options" do
      assert QuintoAndar.build_url() ==
               "https://dummy-quintoandar.test/alugar/imovel/sao-paulo-sp-brasil"
    end

    test "builds sale URL with state and city" do
      url = QuintoAndar.build_url(%{state: "rj", city: "rio-de-janeiro", type: :venda})
      assert url == "https://dummy-quintoandar.test/comprar/imovel/rio-de-janeiro-rj-brasil"
    end

    test "builds URL with neighborhood, property_type, bedrooms and garages" do
      url =
        QuintoAndar.build_url(%{
          state: "sp",
          city: "sao-paulo",
          neighborhood: "moema",
          type: :aluguel,
          property_type: "apartamento",
          bedrooms: 2,
          garages: 1,
          min_price: 2000,
          max_price: 5000
        })

      assert url =~
               "https://dummy-quintoandar.test/alugar/imovel/moema-sao-paulo-sp-brasil/apartamentos/2-quartos/1-vaga?"

      assert url =~ "price_min=2000"
      assert url =~ "price_max=5000"
    end

    test "builds URL for house type" do
      url =
        QuintoAndar.build_url(%{
          state: "pr",
          city: "curitiba",
          property_type: "casa",
          bedrooms: 3
        })

      assert url ==
               "https://dummy-quintoandar.test/alugar/imovel/curitiba-pr-brasil/casas/3-quartos"
    end
  end

  describe "extract_next_data/1" do
    test "successfully extracts and decodes __NEXT_DATA__ script JSON" do
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
            {"props": {"pageProps": {"initialState": {"houses": {}}}}}
          </script>
        </head>
        <body></body>
      </html>
      """

      assert {:ok, %{"props" => %{"pageProps" => %{"initialState" => %{"houses" => %{}}}}}} =
               QuintoAndar.extract_next_data(html)
    end

    test "returns error when script tag is missing" do
      html = "<html><body><h1>No script</h1></body></html>"
      assert QuintoAndar.extract_next_data(html) == {:error, :next_data_script_not_found}
    end
  end

  describe "parse_next_data/1 and normalize_house/1" do
    test "parses houses map and normalizes property fields" do
      json = %{
        "props" => %{
          "pageProps" => %{
            "initialState" => %{
              "houses" => %{
                "12345" => %{
                  "id" => "12345",
                  "type" => "Apartamento",
                  "bedrooms" => 2,
                  "bathrooms" => 1,
                  "parkingSpots" => 1,
                  "area" => 65,
                  "rentPrice" => 3200,
                  "salePrice" => 450_000,
                  "forRent" => true,
                  "forSale" => false,
                  "shortRentDescription" => "Lindo apartamento com 2 quartos para alugar.",
                  "neighbourhood" => "Moema",
                  "address" => %{
                    "address" => "Avenida Ibirapuera",
                    "city" => "São Paulo"
                  },
                  "photos" => [
                    %{"url" => "sample_photo1.jpg"},
                    %{"url" => "https://images.test/photo2.jpg"}
                  ],
                  "banner" => "sample_banner.jpg"
                }
              }
            }
          }
        }
      }

      assert {:ok, result} = QuintoAndar.parse_next_data(json)
      assert result.total == 1
      assert [prop | _] = result.properties

      assert prop.external_id == "quintoandar-12345"
      assert prop.title == "Lindo apartamento com 2 quartos para alugar."
      assert prop.price == 3200
      assert prop.source == "quintoandar"
      assert prop.url == "https://dummy-quintoandar.test/imovel/12345"
      assert prop.location.city == "São Paulo"
      assert prop.location.neighborhood == "Moema"
      assert prop.details.rooms == 2
      assert prop.details.bathrooms == 1
      assert prop.details.garage_spaces == 1
      assert prop.details.area_m2 == 65

      assert prop.images == [
               "https://dummy-quintoandar.test/img/med/sample_photo1.jpg",
               "https://images.test/photo2.jpg"
             ]
    end
  end

  describe "fetch_properties/1" do
    test "fetches and parses properties with in-memory filtering" do
      html = """
      <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
            {
              "props": {
                "pageProps": {
                  "initialState": {
                    "houses": {
                      "1": {
                        "id": "1",
                        "type": "Apartamento",
                        "rentPrice": 2500,
                        "forRent": true,
                        "bedrooms": 2,
                        "parkingSpots": 1,
                        "neighbourhood": "Bela Vista",
                        "address": {"city": "São Paulo"}
                      },
                      "2": {
                        "id": "2",
                        "type": "Apartamento",
                        "rentPrice": 5000,
                        "forRent": true,
                        "bedrooms": 4,
                        "parkingSpots": 2,
                        "neighbourhood": "Jardins",
                        "address": {"city": "São Paulo"}
                      }
                    }
                  }
                }
              }
            }
          </script>
        </head>
        <body></body>
      </html>
      """

      custom_client = fn _url, _headers -> {:ok, html} end

      assert {:ok, res} =
               QuintoAndar.fetch_properties(%{
                 http_client: custom_client,
                 max_price: 3000,
                 bedrooms: 2
               })

      assert res.total == 1
      assert hd(res.properties).external_id == "quintoandar-1"
    end

    test "filters by property_type strictly in memory, excluding apartments when searching for casas" do
      html = """
      <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
            {
              "props": {
                "pageProps": {
                  "initialState": {
                    "houses": {
                      "10": {
                        "id": "10",
                        "type": "Apartamento",
                        "houseType": "APARTMENT",
                        "rentPrice": 2500,
                        "forRent": true,
                        "bedrooms": 2,
                        "neighbourhood": "Pinheiros",
                        "address": {"city": "São Paulo"}
                      },
                      "20": {
                        "id": "20",
                        "type": "Casa em condomínio",
                        "houseType": "CONDO_HOUSE",
                        "rentPrice": 4500,
                        "forRent": true,
                        "bedrooms": 3,
                        "neighbourhood": "Morumbi",
                        "address": {"city": "São Paulo"}
                      },
                      "30": {
                        "id": "30",
                        "type": "Sobrado",
                        "houseType": "HOUSE",
                        "rentPrice": 3800,
                        "forRent": true,
                        "bedrooms": 3,
                        "neighbourhood": "Vila Mariana",
                        "address": {"city": "São Paulo"}
                      }
                    }
                  }
                }
              }
            }
          </script>
        </head>
        <body></body>
      </html>
      """

      custom_client = fn _url, _headers -> {:ok, html} end

      assert {:ok, res} =
               QuintoAndar.fetch_properties(%{
                 http_client: custom_client,
                 property_type: "casa"
               })

      assert res.total == 2
      ids = Enum.map(res.properties, & &1.external_id)
      assert "quintoandar-20" in ids
      assert "quintoandar-30" in ids
      refute "quintoandar-10" in ids
    end
  end
end
