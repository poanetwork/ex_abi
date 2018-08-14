defmodule ABITest do
  use ExUnit.Case
  doctest ABI

  import ABI

  alias ABI.FunctionSelector

  describe "parse_specification/1" do
    test "parses an ABI" do
      abi = [
        %{
          "constant" => true,
          "inputs" => [
            %{
              "type" => "uint256",
              "name" => ""
            }
          ],
          "name" => "fooBar",
          "outputs" => [
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
              "type" => "uint256[3]"
            },
            %{
              "name" => "",
              "type" => "string"
            }
          ],
          "payable" => false,
          "type" => "function"
        },
        %{
          "name" => "baz",
          "type" => "function",
          "outputs" => [
            %{
              "name" => "",
              "type" => "tuple",
              "components" => [
                %{
                  "name" => "",
                  "type" => "uint256"
                },
                %{
                  "name" => "",
                  "type" => "uint256"
                }
              ]
            },
            %{
              "name" => "",
              "type" => "string"
            }
          ],
          "inputs" => []
        }
      ]

      expected = [
        %FunctionSelector{
          function: "fooBar",
          types: [{:uint, 256}],
          returns: [{:array, {:uint, 256}, 6}, :bool, {:array, {:uint, 256}, 3}, :string]
        },
        %FunctionSelector{
          function: "baz",
          types: [],
          returns: [{:tuple, [{:uint, 256}, {:uint, 256}]}, :string]
        }
      ]

      assert parse_specification(abi) == expected
    end
  end
end
