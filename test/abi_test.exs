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
              "name" => "foo"
            }
          ],
          "name" => "fooBar",
          "outputs" => [
            %{
              "name" => "foo",
              "type" => "uint256[6]"
            },
            %{
              "name" => "bar",
              "type" => "bool"
            },
            %{
              "name" => "baz",
              "type" => "uint256[3]"
            },
            %{
              "name" => "buz",
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
                  "name" => "foo",
                  "type" => "uint256"
                },
                %{
                  "name" => "bar",
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
        },
        %{
          "name" => "sam",
          "type" => "function",
          "inputs" => [
            %{
              "type" => "bytes",
              "name" => "foo"
            },
            %{
              "type" => "bool",
              "name" => "bar"
            },
            %{
              "type" => "uint256[]",
              "name" => "baz"
            }
          ],
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
          ]
        }
      ]

      expected = [
        %FunctionSelector{
          type: :function,
          function: "fooBar",
          input_names: ["foo"],
          types: [{:uint, 256}],
          returns: [{:array, {:uint, 256}, 6}, :bool, {:array, {:uint, 256}, 3}, :string],
          method_id: <<245, 72, 246, 70>>
        },
        %FunctionSelector{
          type: :function,
          function: "baz",
          types: [],
          returns: [{:tuple, [{:uint, 256}, {:uint, 256}]}, :string],
          method_id: <<167, 145, 111, 172>>
        },
        %FunctionSelector{
          type: :function,
          function: "sam",
          input_names: ["foo", "bar", "baz"],
          types: [:bytes, :bool, {:array, {:uint, 256}}],
          returns: [{:tuple, [{:uint, 256}, {:uint, 256}]}, :string],
          method_id: <<165, 100, 59, 242>>
        }
      ]

      assert parse_specification(abi) == expected
    end

    test "temp" do # the same as inn doctest
      res =
        ABI.encode("(string)", [{"Ether Token"}])
        |> Base.encode16(case: :lower)

      assert res ==
               "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"
    end
  end
end
