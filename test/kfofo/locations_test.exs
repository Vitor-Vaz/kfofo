defmodule Kfofo.LocationsTest do
  use ExUnit.Case, async: true

  alias Kfofo.Locations

  describe "slugify/1" do
    test "converts accented Brazilian cities and neighborhoods into clean slugs" do
      assert Locations.slugify("São Paulo") == "sao-paulo"
      assert Locations.slugify("Santa Bárbara d'Oeste") == "santa-barbara-doeste"
      assert Locations.slugify("Brasília") == "brasilia"
      assert Locations.slugify("Goiânia") == "goiania"
      assert Locations.slugify("São José dos Campos") == "sao-jose-dos-campos"
      assert Locations.slugify(nil) == nil
      assert Locations.slugify("") == ""
    end
  end

  describe "search_locations/2" do
    test "returns empty list immediately for blank or short queries" do
      assert Locations.search_locations("") == {:ok, []}
      assert Locations.search_locations("a") == {:ok, []}
      assert Locations.search_locations(nil) == {:ok, []}
    end

    test "parses and normalizes predictions from Google Places Autocomplete" do
      mock_client = fn url, [json: payload, headers: headers] ->
        assert url =~ "places:autocomplete"
        assert payload["input"] == "Moema"
        assert payload["includedRegionCodes"] == ["br"]
        assert payload["includedPrimaryTypes"] == ["(regions)"]
        assert {"content-type", "application/json"} in headers

        body = %{
          "suggestions" => [
            %{
              "placePrediction" => %{
                "placeId" => "ChIJp9m429tYzpQR7",
                "text" => %{"text" => "Moema, São Paulo - SP, Brasil"},
                "structuredFormat" => %{
                  "mainText" => %{"text" => "Moema"},
                  "secondaryText" => %{"text" => "São Paulo - SP, Brasil"}
                },
                "types" => ["sublocality_level_1", "sublocality", "political"]
              }
            },
            %{
              "placePrediction" => %{
                "placeId" => "establishment_123",
                "text" => %{"text" => "Bangu Shopping, Rio de Janeiro - RJ"},
                "types" => ["shopping_mall", "establishment", "point_of_interest"]
              }
            },
            %{
              "placePrediction" => %{
                "placeId" => "country_123",
                "text" => %{"text" => "Brasil"},
                "types" => ["country", "political"]
              }
            }
          ]
        }

        {:ok, %{status: 200, body: body}}
      end

      assert {:ok, [prediction]} =
               Locations.search_locations("Moema", http_client: mock_client)

      assert prediction.place_id == "ChIJp9m429tYzpQR7"
      assert prediction.description == "Moema, São Paulo - SP, Brasil"
      assert prediction.main_text == "Moema"
      assert prediction.secondary_text == "São Paulo - SP, Brasil"
      assert "sublocality_level_1" in prediction.types
    end

    test "handles empty suggestions gracefully" do
      mock_client = fn _url, _opts ->
        {:ok, %{status: 200, body: %{"suggestions" => []}}}
      end

      assert Locations.search_locations("localizacaoinvalida123", http_client: mock_client) ==
               {:ok, []}
    end

    test "handles Google API error responses" do
      mock_client = fn _url, _opts ->
        {:ok,
         %{
           status: 403,
           body: %{
             "error" => %{
               "status" => "REQUEST_DENIED",
               "message" => "The provided API key is invalid."
             }
           }
         }}
      end

      assert {:error,
              {:google_places_error, "REQUEST_DENIED", "The provided API key is invalid."}} =
               Locations.search_locations("Moema", http_client: mock_client)
    end

    test "returns error when API key is missing" do
      assert Locations.search_locations("Moema", api_key: nil) == {:error, :missing_api_key}
      assert Locations.search_locations("Moema", api_key: "") == {:error, :missing_api_key}
    end
  end

  describe "get_location_details/2" do
    test "fetches and normalizes address components from Google Place Details" do
      mock_client = fn url, [params: _params, headers: headers] ->
        assert url =~ "places/place_123"
        assert {"x-goog-api-key", "dummy_test_key"} in headers

        body = %{
          "id" => "place_123",
          "formattedAddress" => "Moema, São Paulo - SP, Brasil",
          "addressComponents" => [
            %{
              "longText" => "Moema",
              "shortText" => "Moema",
              "types" => ["sublocality_level_1", "sublocality", "political"]
            },
            %{
              "longText" => "São Paulo",
              "shortText" => "São Paulo",
              "types" => ["administrative_area_level_2", "political"]
            },
            %{
              "longText" => "São Paulo",
              "shortText" => "SP",
              "types" => ["administrative_area_level_1", "political"]
            },
            %{
              "longText" => "Brasil",
              "shortText" => "BR",
              "types" => ["country", "political"]
            }
          ],
          "location" => %{
            "latitude" => -23.6033,
            "longitude" => -46.6631
          }
        }

        {:ok, %{status: 200, body: body}}
      end

      assert {:ok, details} =
               Locations.get_location_details("place_123", http_client: mock_client)

      assert details.place_id == "place_123"
      assert details.formatted_address == "Moema, São Paulo - SP, Brasil"
      assert details.state == "sp"
      assert details.state_name == "São Paulo"
      assert details.city == "sao-paulo"
      assert details.city_name == "São Paulo"
      assert details.neighborhood == "moema"
      assert details.neighborhood_name == "Moema"
      assert details.lat == -23.6033
      assert details.lng == -46.6631
    end

    test "returns error for invalid place_id" do
      assert Locations.get_location_details("") == {:error, :invalid_place_id}
      assert Locations.get_location_details(nil) == {:error, :invalid_place_id}
    end
  end
end
