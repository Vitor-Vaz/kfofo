defmodule Kfofo.PropertiesTest do
  use ExUnit.Case, async: false

  alias Kfofo.Properties
  alias Kfofo.Properties.Store

  setup do
    Store.clear()
    :ok
  end

  describe "Properties.Store" do
    test "saves and retrieves a property by external_id" do
      property = %{
        external_id: "test-prop-1",
        title: "Apartamento em Copacabana",
        price: 2500,
        url: "https://example.com/prop-1",
        source: "olx",
        location: %{city: "Rio de Janeiro", neighborhood: "Copacabana"},
        details: %{bedrooms: 2, bathrooms: 1, garage_spaces: 1, area_sqm: 60},
        images: ["https://example.com/img1.jpg"]
      }

      assert :ok = Properties.save_property(property)
      assert {:ok, fetched} = Properties.get_property("test-prop-1")
      assert fetched.title == "Apartamento em Copacabana"
      assert fetched.price == 2500
    end

    test "saves multiple properties with save_properties/1" do
      props = [
        %{external_id: "prop-a", title: "Imóvel A", price: 1000},
        %{external_id: "prop-b", title: "Imóvel B", price: 2000}
      ]

      assert :ok = Properties.save_properties(props)
      assert {:ok, a} = Properties.get_property("prop-a")
      assert a.title == "Imóvel A"
      assert {:ok, b} = Properties.get_property("prop-b")
      assert b.title == "Imóvel B"
    end

    test "returns {:error, :not_found} for non-existent external_id" do
      assert {:error, :not_found} = Properties.get_property("non-existent-id")
    end

    test "handles invalid inputs gracefully" do
      assert {:error, :invalid_property} = Store.put(nil)
      assert {:error, :missing_external_id} = Store.put(%{title: "No ID"})
      assert {:error, :invalid_properties_list} = Store.put_all("invalid")
      assert {:error, :invalid_id} = Store.get(nil)
    end
  end
end
