defmodule ABI.TypeEncoderTest do
  use ExUnit.Case, async: true
  doctest ABI.TypeEncoder

  describe "encode/2 '{:int, size}' type" do
    test "successfully encodes positive and negative values" do
      data_to_encode = [42, -42]

      selector = %ABI.FunctionSelector{
        function: "baz",
        types: [
          {:int, 8},
          {:int, 16}
        ],
        returns: :bool
      }

      encrypted_fn_name = "64ea0ab7"
      # 42
      positive_int = "000000000000000000000000000000000000000000000000000000000000002a"
      # -42
      negative_int = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd6"

      expected_result =
        Base.decode16!(encrypted_fn_name <> positive_int <> negative_int, case: :lower)

      assert ABI.TypeEncoder.encode(data_to_encode, selector) == expected_result
    end

    test "raises when there is signed integer overflow" do
      # an 8 bit signed integer must be between -127 and 127
      data_to_encode = [128]

      selector = %ABI.FunctionSelector{
        function: "baz",
        types: [
          {:int, 8}
        ],
        returns: :bool
      }

      assert_raise RuntimeError, fn ->
        ABI.TypeEncoder.encode(data_to_encode, selector)
      end
    end

    # test "temp" do # the same as in doctest
    #   res =
    #     [{"awesome", true}]
    #     |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
    #       function: nil,
    #       types: [
    #         {:tuple, [:string, :bool]}
    #       ]
    #     })
    #     |> Base.encode16(case: :lower)

    #   assert res ==
    #            "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
    # end

    # test "temp2" do # the same as in doctest
    #   res =
    #     ["hello world"]
    #     |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
    #       function: nil,
    #       types: [
    #         :string
    #       ]
    #     })
    #     |> Base.encode16(case: :lower)

    #   assert res ==
    #            "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"
    # end
  end
end
