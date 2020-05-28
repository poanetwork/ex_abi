defmodule ABI.FunctionSelectorTest do
  use ExUnit.Case, async: true
  doctest ABI.FunctionSelector

  alias ABI.FunctionSelector

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

      assert FunctionSelector.parse_specification_type(type) == expected
    end
  end

  describe "parse_specification_item/1" do
    test "parses constructor" do
      abi = %{
        "type" => "constructor",
        "inputs" => [
          %{"type" => "address", "name" => "_golemFactory"},
          %{"type" => "address", "name" => "_migrationMaster"},
          %{"type" => "uint256", "name" => "_fundingStartBlock"},
          %{"type" => "uint256", "name" => "_fundingEndBlock"}
        ]
      }

      assert FunctionSelector.parse_specification_item(abi) == %FunctionSelector{
               function: nil,
               input_names: [
                 "_golemFactory",
                 "_migrationMaster",
                 "_fundingStartBlock",
                 "_fundingEndBlock"
               ],
               inputs_indexed: nil,
               method_id: <<145, 100, 21, 225>>,
               returns: [],
               type: :constructor,
               types: [:address, :address, {:uint, 256}, {:uint, 256}]
             }
    end

    test "parses array of tuples" do
      function = %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "uint160[]", "name" => "exitIds", "type" => "uint160[]"}
        ],
        "name" => "standardExits",
        "outputs" => [
          %{
            "components" => [
              %{"internalType" => "bool", "name" => "exitable", "type" => "bool"},
              %{"internalType" => "uint256", "name" => "utxoPos", "type" => "uint256"},
              %{
                "internalType" => "bytes32",
                "name" => "outputId",
                "type" => "bytes32"
              },
              %{
                "internalType" => "address payable",
                "name" => "exitTarget",
                "type" => "address"
              },
              %{"internalType" => "uint256", "name" => "amount", "type" => "uint256"},
              %{
                "internalType" => "uint256",
                "name" => "bondSize",
                "type" => "uint256"
              }
            ],
            "internalType" => "struct PaymentExitDataModel.StandardExit[]",
            "name" => "",
            "type" => "tuple[]"
          }
        ],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }

      expected_type = [
        array: {:tuple, [:bool, {:uint, 256}, {:bytes, 32}, :address, {:uint, 256}, {:uint, 256}]}
      ]

      selector = FunctionSelector.parse_specification_item(function)

      assert expected_type == selector.returns
    end
  end
end
