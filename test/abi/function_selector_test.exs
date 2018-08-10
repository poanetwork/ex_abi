defmodule ABI.FunctionSelectorTest do
  use ExUnit.Case, async: true
  doctest ABI.FunctionSelector

  import ABI.FunctionSelector

  describe "parse_specification_type/1" do
    test "with a tuple and components" do
      type = %{
        "name" => "",
        "type" => "tuple",
        "components" => [
          %{
            "name" => "",
            "type" => "uint256[6]"
          },
          %{
            "name" => "",
            "type" => "bool"
          },
          %{
            "name" => "",
            "type" => "uint256[24]"
          },
          %{
            "name" => "",
            "type" => "bool[24]"
          },
          %{
            "name" => "",
            "type" => "uint256"
          },
          %{
            "name" => "",
            "type" => "uint256"
          },
          %{
            "name" => "",
            "type" => "uint256"
          },
          %{
            "name" => "",
            "type" => "uint256"
          },
          %{
            "name" => "",
            "type" => "string"
          }
        ]
      }

      expected = {
        :tuple,
        [
         {:array, {:uint, 256}, 6},
         :bool,
         {:array, {:uint, 256}, 24},
         {:array, :bool, 24},
         {:uint, 256},
         {:uint, 256},
         {:uint, 256},
         {:uint, 256},
         :string
        ]
      }

      assert parse_specification_type(type) == expected
    end
  end
end
