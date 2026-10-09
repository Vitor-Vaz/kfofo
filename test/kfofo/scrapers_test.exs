defmodule Kfofo.ScrapersTest do
  use ExUnit.Case, async: true

  alias Kfofo.Scrapers

  describe "fetch_all_properties/1" do
    test "concurrently aggregates properties from multiple scrapers" do
      mock_olx = fn _opts ->
        {:ok,
         %{
           properties: [
             %{external_id: "olx-100", title: "Apartamento OLX", price: 2000, source: "olx"}
           ],
           total: 1
         }}
      end

      mock_quintoandar = fn _opts ->
        {:ok,
         %{
           properties: [
             %{
               external_id: "quintoandar-200",
               title: "Casa QuintoAndar",
               price: 3500,
               source: "quintoandar"
             }
           ],
           total: 1
         }}
      end

      custom_scrapers = [
        {:olx, mock_olx},
        {:quintoandar, mock_quintoandar}
      ]

      assert {:ok, res} =
               Scrapers.fetch_all_properties(%{
                 scrapers: custom_scrapers,
                 state: "sp",
                 city: "sao-paulo"
               })

      assert res.total == 2
      sources = Enum.map(res.properties, & &1.source)
      assert "olx" in sources
      assert "quintoandar" in sources
    end

    test "interleaves listings across portals in fair distribution" do
      mock_olx = fn _opts ->
        {:ok,
         %{
           properties: [
             %{external_id: "olx-1", title: "OLX 1", price: 1000, source: "olx"},
             %{external_id: "olx-2", title: "OLX 2", price: 1200, source: "olx"}
           ]
         }}
      end

      mock_quintoandar = fn _opts ->
        {:ok,
         %{
           properties: [
             %{external_id: "qa-1", title: "QA 1", price: 2000, source: "quintoandar"},
             %{external_id: "qa-2", title: "QA 2", price: 2200, source: "quintoandar"}
           ]
         }}
      end

      custom_scrapers = [
        {:olx, mock_olx},
        {:quintoandar, mock_quintoandar}
      ]

      assert {:ok, res} = Scrapers.fetch_all_properties(%{scrapers: custom_scrapers})
      ids = Enum.map(res.properties, & &1.external_id)
      assert ids == ["olx-1", "qa-1", "olx-2", "qa-2"]
    end

    test "deduplicates properties with matching external_ids" do
      mock_scraper1 = fn _opts ->
        {:ok, %{properties: [%{external_id: "prop-1", title: "Imóvel 1", price: 1500}]}}
      end

      mock_scraper2 = fn _opts ->
        {:ok, %{properties: [%{external_id: "prop-1", title: "Imóvel 1", price: 1500}]}}
      end

      custom_scrapers = [
        {:s1, mock_scraper1},
        {:s2, mock_scraper2}
      ]

      assert {:ok, res} = Scrapers.fetch_all_properties(%{scrapers: custom_scrapers})
      assert res.total == 1
    end

    test "handles partial failure gracefully when one scraper succeeds" do
      mock_olx = fn _opts -> {:error, {:network_error, :timeout}} end

      mock_quintoandar = fn _opts ->
        {:ok,
         %{
           properties: [
             %{
               external_id: "quintoandar-555",
               title: "Apartamento QuintoAndar",
               price: 4000,
               source: "quintoandar"
             }
           ],
           total: 1
         }}
      end

      custom_scrapers = [
        {:olx, mock_olx},
        {:quintoandar, mock_quintoandar}
      ]

      assert {:ok, res} = Scrapers.fetch_all_properties(%{scrapers: custom_scrapers})
      assert res.total == 1
      assert hd(res.properties).external_id == "quintoandar-555"
    end
  end
end
