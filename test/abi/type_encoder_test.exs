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
  end

  describe "encode" do
    test "encode array of addresses" do
      res =
        [
          [
            <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202,
              246>>,
            <<170, 148, 182, 135, 211, 249, 85, 42, 69, 59, 129, 178, 131, 76, 165, 55, 120, 152,
              13, 192>>,
            <<49, 44, 35, 14, 125, 109, 176, 82, 36, 246, 2, 8, 166, 86, 227, 84, 28, 92, 66,
              186>>
          ]
        ]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: nil,
          types: [
            {:array, :address}
          ]
        })
        |> Base.encode16(case: :lower)

      assert res ==
               "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6000000000000000000000000aa94b687d3f9552a453b81b2834ca53778980dc0000000000000000000000000312c230e7d6db05224f60208a656e3541c5c42ba"
    end
  end
end
