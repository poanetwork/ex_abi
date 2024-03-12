defmodule ABI.FunctionSelectorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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

    test "parses multidimensional tuple array" do
      abi = %{
        "constant" => true,
        "inputs" => [
          %{
            "name" => "swaps",
            "type" => "tuple[][]",
            "interalType" => "struct ExchangeProxy.Swap[][]",
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
          }
        ],
        "name" => "batchSwapExactOut",
        "outputs" => [%{"name" => "totalAmountIn", "type" => "uint256"}],
        "payable" => true,
        "stateMutability" => "payable",
        "type" => "function"
      }

      assert [
               %ABI.FunctionSelector{
                 function: "batchSwapExactOut",
                 input_names: ["swaps"],
                 inputs_indexed: nil,
                 method_id: <<33, 173, 158, 39>>,
                 returns: [uint: 256],
                 return_names: ["totalAmountIn"],
                 type: :function,
                 types: [array: {:array, {:tuple, [uint: 256, uint: 256]}}],
                 state_mutability: :payable
               }
             ] == ABI.parse_specification([abi])
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

    test "parses error" do
      error = %{
        "inputs" => [
          %{
            "internalType" => "uint256",
            "name" => "reason",
            "type" => "uint256"
          }
        ],
        "name" => "DummyError",
        "type" => "error"
      }

      assert %ABI.FunctionSelector{
               function: "DummyError",
               input_names: ["reason"],
               inputs_indexed: nil,
               method_id: <<26, 23, 164, 46>>,
               returns: [],
               type: :error,
               types: [uint: 256]
             } = FunctionSelector.parse_specification_item(error)
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

    test "parses fixed array of tuples" do
      function = %{
        "constant" => false,
        "inputs" => [
          %{"internalType" => "uint160", "name" => "exitId", "type" => "uint160"},
          %{
            "components" => [
              %{"internalType" => "bool", "name" => "isCanonical", "type" => "bool"},
              %{
                "internalType" => "uint64",
                "name" => "exitStartTimestamp",
                "type" => "uint64"
              },
              %{"internalType" => "uint256", "name" => "exitMap", "type" => "uint256"},
              %{
                "internalType" => "uint256",
                "name" => "position",
                "type" => "uint256"
              },
              %{
                "components" => [
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
                  %{
                    "internalType" => "address",
                    "name" => "token",
                    "type" => "address"
                  },
                  %{
                    "internalType" => "uint256",
                    "name" => "amount",
                    "type" => "uint256"
                  },
                  %{
                    "internalType" => "uint256",
                    "name" => "piggybackBondSize",
                    "type" => "uint256"
                  }
                ],
                "internalType" => "struct PaymentExitDataModel.WithdrawData[4]",
                "name" => "inputs",
                "type" => "tuple[4]"
              },
              %{
                "components" => [
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
                  %{
                    "internalType" => "address",
                    "name" => "token",
                    "type" => "address"
                  },
                  %{
                    "internalType" => "uint256",
                    "name" => "amount",
                    "type" => "uint256"
                  },
                  %{
                    "internalType" => "uint256",
                    "name" => "piggybackBondSize",
                    "type" => "uint256"
                  }
                ],
                "internalType" => "struct PaymentExitDataModel.WithdrawData[4]",
                "name" => "outputs",
                "type" => "tuple[4]"
              },
              %{
                "internalType" => "address payable",
                "name" => "bondOwner",
                "type" => "address"
              },
              %{
                "internalType" => "uint256",
                "name" => "bondSize",
                "type" => "uint256"
              },
              %{
                "internalType" => "uint256",
                "name" => "oldestCompetitorPosition",
                "type" => "uint256"
              }
            ],
            "internalType" => "struct PaymentExitDataModel.InFlightExit",
            "name" => "exit",
            "type" => "tuple"
          }
        ],
        "name" => "setInFlightExit",
        "outputs" => [],
        "payable" => false,
        "stateMutability" => "nonpayable",
        "type" => "function"
      }

      expected_type = [
        {:uint, 160},
        {:tuple,
         [
           :bool,
           {:uint, 64},
           {:uint, 256},
           {:uint, 256},
           {:array, {:tuple, [{:bytes, 32}, :address, :address, {:uint, 256}, {:uint, 256}]}, 4},
           {:array, {:tuple, [{:bytes, 32}, :address, :address, {:uint, 256}, {:uint, 256}]}, 4},
           :address,
           {:uint, 256},
           {:uint, 256}
         ]}
      ]

      selector = FunctionSelector.parse_specification_item(function)

      assert expected_type == selector.types
    end

    test "parses fixed 2D array of tuples" do
      function = %{
        "inputs" => [],
        "name" => "createTupleArray",
        "outputs" => [
          %{
            "components" => [
              %{
                "internalType" => "uint256",
                "name" => "element1",
                "type" => "uint256"
              },
              %{"internalType" => "bool", "name" => "element2", "type" => "bool"}
            ],
            "internalType" => "struct StorageB.MyTuple[2][]",
            "name" => "",
            "type" => "tuple[2][]"
          }
        ],
        "stateMutability" => "pure",
        "type" => "function"
      }

      expected = [
        array: {:array, {:tuple, [{:uint, 256}, :bool]}, 2}
      ]

      selector = FunctionSelector.parse_specification_item(function)

      assert expected == selector.returns
    end

    test "with stateMutability set" do
      ~w(pure view nonpayable payable)
      |> Enum.zip(~w(pure view non_payable payable)a)
      |> Enum.each(fn {state_mutability, state_mutability_atom} ->
        function = %{
          "inputs" => [
            %{"internalType" => "uint160[]", "name" => "exitIds", "type" => "uint160[]"}
          ],
          "name" => "standardExits",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => state_mutability,
          "type" => "function"
        }

        assert %FunctionSelector{state_mutability: ^state_mutability_atom} =
                 FunctionSelector.parse_specification_item(function)
      end)
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

      assert FunctionSelector.simple_types?(types, %{})
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

      assert FunctionSelector.simple_types?(types, %{})
    end

    test "invalidates complex type" do
      types = [
        %{
          "internalType" => "contract PlasmaFramework",
          "name" => "framework",
          "type" => "PlasmaFramework"
        }
      ]

      assert capture_log(fn ->
               refute FunctionSelector.simple_types?(types, %{})
             end) =~
               "Can not parse %{} because it contains complex types"
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

      assert capture_log(fn ->
               refute FunctionSelector.simple_types?(types, %{})
             end) =~
               "Can not parse %{} because it contains complex types"
    end
  end
end
