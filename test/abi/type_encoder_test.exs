defmodule ABI.TypeEncoderTest do
  use ExUnit.Case, async: true

  # doctest ABI.TypeEncoder

  # describe "encode/2 '{:int, size}' type" do
  #   test "successfully encodes positive and negative values" do
  #     data_to_encode = [42, -42]

  #     selector = %ABI.FunctionSelector{
  #       function: "baz",
  #       types: [
  #         {:int, 8},
  #         {:int, 16}
  #       ],
  #       returns: :bool
  #     }

  #     encrypted_fn_name = "64ea0ab7"
  #     # 42
  #     positive_int = "000000000000000000000000000000000000000000000000000000000000002a"
  #     # -42
  #     negative_int = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd6"

  #     expected_result =
  #       Base.decode16!(encrypted_fn_name <> positive_int <> negative_int, case: :lower)

  #     assert ABI.TypeEncoder.encode(data_to_encode, selector) == expected_result
  #   end

  #   test "raises when there is signed integer overflow" do
  #     # an 8 bit signed integer must be between -127 and 127
  #     data_to_encode = [128]

  #     selector = %ABI.FunctionSelector{
  #       function: "baz",
  #       types: [
  #         {:int, 8}
  #       ],
  #       returns: :bool
  #     }

  #     assert_raise RuntimeError, fn ->
  #       ABI.TypeEncoder.encode(data_to_encode, selector)
  #     end
  #   end
  # end

  #   test "encode bytes" do
  #     data = [<<1, 35, 69, 103, 137>>]

  #     function_selector = %ABI.FunctionSelector{
  #       function: nil,
  #       types: [:bytes]
  #     }

  #     encoded_pattern =
  #       """
  #       0000000000000000000000000000000000000000000000000000000000000020
  #       0000000000000000000000000000000000000000000000000000000000000005
  #       0123456789000000000000000000000000000000000000000000000000000000
  #       """
  #       |> encode_multiline_string()

  #     assert Base.encode16(ABI.TypeEncoder.encode(data, function_selector), case: :lower) ==
  #              Base.encode16(encoded_pattern, case: :lower)

  #     data = [<<1, 35, 69, 103, 137>>]

  #     function_selector = %ABI.FunctionSelector{
  #       function: "returnBytes1",
  #       input_names: ["arr"],
  #       inputs_indexed: nil,
  #       method_id: <<223, 65, 143, 191>>,
  #       returns: [:bytes],
  #       type: :function,
  #       types: [:bytes]
  #     }

  #     encoded_pattern =
  #       """
  #       df418fbf
  #       0000000000000000000000000000000000000000000000000000000000000020
  #       0000000000000000000000000000000000000000000000000000000000000005
  #       0123456789000000000000000000000000000000000000000000000000000000
  #       """
  #       |> encode_multiline_string()

  #     assert Base.encode16(ABI.encode(function_selector, data), case: :lower) ==
  #              Base.encode16(encoded_pattern, case: :lower)
  #   end

  #   test "encodes [string, bool]" do
  #     data_to_encode = [{"awesome", true}]

  #     selector = %ABI.FunctionSelector{
  #       types: [{:tuple, [:string, :bool]}]
  #     }

  #     encoded_pattern =
  #       """
  #       0000000000000000000000000000000000000000000000000000000000000040
  #       0000000000000000000000000000000000000000000000000000000000000001
  #       0000000000000000000000000000000000000000000000000000000000000007
  #       617765736f6d6500000000000000000000000000000000000000000000000000
  #       """
  #       |> encode_multiline_string()

  #     assert Base.encode16(ABI.TypeEncoder.encode(data_to_encode, selector), case: :lower) ==
  #              Base.encode16(encoded_pattern, case: :lower)
  #   end

  # end

  describe "encode/2" do
    test "encodes [{:uint, 32}, :bool]" do
      result =
        [69, true]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: "baz",
          types: [
            {:uint, 32},
            :bool
          ],
          returns: :bool
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "cdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"

      assert expected_result == result
    end

    test "encodes [{:int, 25}, :bool]" do
      result =
        [-5678, true]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: "baz",
          types: [
            {:int, 256},
            :bool
          ],
          returns: :bool
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "d7aeca2bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe9d20000000000000000000000000000000000000000000000000000000000000001"

      assert result == expected_result
    end

    test "encodes [:string]" do
      result =
        ["hello world"]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: nil,
          types: [
            :string
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"

      assert expected_result == result
    end

    test "encodes [{string, bool}]" do
      result =
        [{"awesome", true}]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: nil,
          types: [
            {:tuple, [:string, :bool]}
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"

      assert expected_result == result
    end

    test "encodes [17, 1]]" do
      result =
        [[17, 1]]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: "baz",
          types: [
            {:array, {:uint, 32}, 2}
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "3d0ec53300000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"

      assert result == expected_result
    end

    test "encodes [[17, 1], true]" do
      result =
        [[17, 1], true]
        |> ABI.TypeEncoder.encode(%ABI.FunctionSelector{
          function: nil,
          types: [
            {:array, {:uint, 32}, 2},
            :bool
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"

      assert result == expected_result
    end

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

    test "encodes [string, bool]" do
      data_to_encode = [{"awesome", true}]

      selector = %ABI.FunctionSelector{
        types: [{:tuple, [:string, :bool]}]
      }

      result = ABI.TypeEncoder.encode(data_to_encode, selector)

      encoded_pattern =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"

      assert Base.encode16(result, case: :lower) ==
               encoded_pattern
    end

    test "encodes [[1], [2]]" do
      data_to_encode = [[1], [2]]
      selector = "test(uint[], uint[])"

      encoded_pattern =
        """
        f0d7f6eb
        0000000000000000000000000000000000000000000000000000000000000040
        0000000000000000000000000000000000000000000000000000000000000080
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000002
        """
        |> encode_multiline_string()

      assert Base.encode16(ABI.encode(selector, data_to_encode), case: :lower) ==
               Base.encode16(encoded_pattern, case: :lower)
    end
  end

  defp encode_multiline_string(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.join()
    |> Base.decode16!(case: :mixed)
  end
end
