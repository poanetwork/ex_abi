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

  describe "simple_types?/1" do
    test "verifies simple types" do
      types = [
        %{
          "internalType" => "uint256",
          "name" => "erc20VaultId",
          "type" => "uint256"
        },
        %{
          "internalType" => "uint256",
          "name" => "supportedTxType",
          "type" => "uint256"
        }
      ]

      assert FunctionSelector.simple_types?(types)
    end

    test "verifies tuple type" do
      types = [
        %{
          "components" => [
            %{
              "internalType" => "uint256",
              "name" => "minExitPeriod",
              "type" => "uint256"
            }
          ],
          "internalType" => "struct ExitableTimestamp.Calculator",
          "name" => "exitableTimestampCalculator",
          "type" => "tuple"
        }
      ]

      assert FunctionSelector.simple_types?(types)
    end

    test "invalidates complex type" do
      types = [
        %{
          "internalType" => "contract PlasmaFramework",
          "name" => "framework",
          "type" => "PlasmaFramework"
        }
      ]

      refute FunctionSelector.simple_types?(types)
    end

    test "invalidates comples tuple type" do
      types = [
        %{
          "components" => [
            %{
              "components" => [
                %{
                  "internalType" => "uint256",
                  "name" => "minExitPeriod",
                  "type" => "uint256"
                }
              ],
              "internalType" => "struct ExitableTimestamp.Calculator",
              "name" => "exitableTimestampCalculator",
              "type" => "tuple"
            },
            %{
              "internalType" => "uint256",
              "name" => "ethVaultId",
              "type" => "uint256"
            },
            %{
              "internalType" => "uint256",
              "name" => "erc20VaultId",
              "type" => "uint256"
            },
            %{
              "internalType" => "uint256",
              "name" => "supportedTxType",
              "type" => "uint256"
            },
            %{
              "internalType" => "contract IExitProcessor",
              "name" => "exitProcessor",
              "type" => "IExitProcessor"
            },
            %{
              "internalType" => "contract PlasmaFramework",
              "name" => "framework",
              "type" => "PlasmaFramework"
            }
          ],
          "internalType" => "struct PaymentStartStandardExit.Controller",
          "name" => "",
          "type" => "tuple"
        }
      ]

      refute FunctionSelector.simple_types?(types)
    end
  end
end
