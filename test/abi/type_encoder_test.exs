defmodule ABI.TypeEncoderTest do
  use ExUnit.Case, async: true

  alias ABI.FunctionSelector
  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  doctest ABI.TypeEncoder

  describe "encode/2" do
    test "encodes [{:uint, 32}, :bool]" do
      params = [69, true]

      types = [
        {:uint, 32},
        :bool
      ]

      selector = %FunctionSelector{
        function: "baz",
        method_id: <<205, 205, 119, 192>>,
        types: types,
        returns: :bool
      }

      result =
        params
        |> TypeEncoder.encode(selector)

      expected_result =
        "cdcd77c000000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
        |> Base.decode16!(case: :lower)

      assert expected_result == result
      assert TypeDecoder.decode(expected_result, selector) == params
    end

    test "encodes [{:int, 256}, :bool]" do
      selector = %FunctionSelector{
        function: "baz",
        method_id: <<215, 174, 202, 43>>,
        types: [
          {:int, 256},
          :bool
        ],
        returns: :bool
      }

      result =
        [-5678, true]
        |> TypeEncoder.encode(selector)

      expected_result =
        "d7aeca2bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe9d20000000000000000000000000000000000000000000000000000000000000001"
        |> Base.decode16!(case: :lower)

      assert result == expected_result

      assert TypeDecoder.decode(expected_result, selector) == [-5678, true]
    end

    test "encodes [:string]" do
      types = [:string]
      params = ["hello world"]

      result =
        ["hello world"]
        |> TypeEncoder.encode(%FunctionSelector{
          function: nil,
          types: [
            :string
          ]
        })

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      assert expected_result == result
      assert TypeDecoder.decode(expected_result, types) == params
    end

    test "encodes [{string, bool}]" do
      params = [{"awesome", true}]

      types = [
        {:tuple, [:string, :bool]}
      ]

      result =
        params
        |> TypeEncoder.encode(%FunctionSelector{
          function: nil,
          types: types
        })

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      assert expected_result == result
      assert TypeDecoder.decode(expected_result, types) == params
    end

    test "encodes [{string, bool}] where tuple as list" do
      params = [["awesome", true]]
      decoded = [{"awesome", true}]

      types = [
        {:tuple, [:string, :bool]}
      ]

      result =
        params
        |> TypeEncoder.encode(%FunctionSelector{
          function: nil,
          types: types
        })

      expected_result =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      assert expected_result == result
      assert TypeDecoder.decode(expected_result, types) == decoded
    end

    test "encodes [17, 1]]" do
      selector = %FunctionSelector{
        function: "baz",
        method_id: <<61, 14, 197, 51>>,
        types: [
          {:array, {:uint, 32}, 2}
        ]
      }

      params = [[17, 1]]

      result =
        params
        |> TypeEncoder.encode(selector)

      expected_result =
        "3d0ec53300000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
        |> Base.decode16!(case: :lower)

      assert result == expected_result
      assert TypeDecoder.decode(expected_result, selector) == params
    end

    test "encodes [[17, 1], true]" do
      params = [[17, 1], true]

      selector = %FunctionSelector{
        function: nil,
        types: [
          {:array, {:uint, 32}, 2},
          :bool
        ]
      }

      result =
        params
        |> ABI.TypeEncoder.encode(selector)

      expected_result =
        "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
        |> Base.decode16!(case: :lower)

      assert result == expected_result
      assert ABI.TypeDecoder.decode(expected_result, selector) == params
    end

    test "encode array of addresses" do
      params = [
        [
          <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202,
            246>>,
          <<170, 148, 182, 135, 211, 249, 85, 42, 69, 59, 129, 178, 131, 76, 165, 55, 120, 152,
            13, 192>>,
          <<49, 44, 35, 14, 125, 109, 176, 82, 36, 246, 2, 8, 166, 86, 227, 84, 28, 92, 66, 186>>
        ]
      ]

      selector = %FunctionSelector{
        function: nil,
        types: [
          {:array, :address}
        ]
      }

      res =
        params
        |> ABI.TypeEncoder.encode(selector)

      expected_result =
        "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6000000000000000000000000aa94b687d3f9552a453b81b2834ca53778980dc0000000000000000000000000312c230e7d6db05224f60208a656e3541c5c42ba"
        |> Base.decode16!(case: :lower)

      assert res == expected_result
      assert ABI.TypeDecoder.decode(expected_result, selector) == params
    end

    test "encodes [string, bool]" do
      data_to_encode = [{"awesome", true}]

      selector = %FunctionSelector{
        types: [{:tuple, [:string, :bool]}]
      }

      result = ABI.TypeEncoder.encode(data_to_encode, selector)

      encoded_pattern =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      assert result ==
               encoded_pattern

      assert ABI.TypeDecoder.decode(encoded_pattern, selector) == data_to_encode
    end

    test "encodes [string, bool] where tuple as list" do
      data_to_encode = [["awesome", true]]
      decoded = [{"awesome", true}]

      selector = %FunctionSelector{
        types: [{:tuple, [:string, :bool]}]
      }

      result = ABI.TypeEncoder.encode(data_to_encode, selector)

      encoded_pattern =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      assert result ==
               encoded_pattern

      assert ABI.TypeDecoder.decode(encoded_pattern, selector) == decoded
    end

    test "encodes [[1], [2]]" do
      data_to_encode = [[1], [2]]
      types = [{:array, {:uint, 256}}, {:array, {:uint, 256}}]
      result = ABI.TypeEncoder.encode(data_to_encode, types)

      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000040
        0000000000000000000000000000000000000000000000000000000000000080
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000001
        0000000000000000000000000000000000000000000000000000000000000002
        """
        |> encode_multiline_string()

      assert Base.encode16(result, case: :lower) ==
               Base.encode16(encoded_pattern, case: :lower)

      assert ABI.TypeDecoder.decode(encoded_pattern, types) == data_to_encode
    end

    test "encode bytes example 1" do
      data = [<<1, 35, 69, 103, 137>>]

      function_selector = %FunctionSelector{
        function: nil,
        types: [:bytes]
      }

      encoded_pattern =
        """
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000005
        0123456789000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert ABI.TypeEncoder.encode(data, function_selector) == encoded_pattern
      assert ABI.TypeDecoder.decode(encoded_pattern, function_selector) == data
    end

    test "encode bytes example 2" do
      data = [<<1, 35, 69, 103, 137>>]

      function_selector = %FunctionSelector{
        function: "returnBytes1",
        input_names: ["arr"],
        inputs_indexed: nil,
        method_id: <<223, 65, 143, 191>>,
        returns: [:bytes],
        type: :function,
        types: [:bytes]
      }

      encoded_pattern =
        """
        df418fbf
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000005
        0123456789000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert ABI.TypeEncoder.encode(data, function_selector) == encoded_pattern
      assert ABI.TypeDecoder.decode(encoded_pattern, function_selector) == data
    end

    test "raises when there is signed integer overflow" do
      # an 8 bit signed integer must be between -127 and 127
      data_to_encode = [128]

      selector = %FunctionSelector{
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

    test "successfully encodes positive and negative values" do
      data_to_encode = [42, -42]

      selector = %FunctionSelector{
        function: "baz",
        method_id: <<100, 234, 10, 183>>,
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
      assert ABI.TypeDecoder.decode(expected_result, selector) == data_to_encode
    end

    test "encodes {:tuple, [{:uint, 32}, :bool, {:bytes, 2}]}" do
      params =
        [{17, true, <<32, 64>>}]
        |> ABI.TypeEncoder.encode(%FunctionSelector{
          function: nil,
          types: [
            {:tuple, [{:uint, 32}, :bool, {:bytes, 2}]}
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000012040000000000000000000000000000000000000000000000000000000000000"

      assert params == expected_result
    end

    test "encodes {:tuple, [{:uint, 32}, :bool, {:bytes, 2}]} where tuple as list" do
      params =
        [[17, true, <<32, 64>>]]
        |> ABI.TypeEncoder.encode(%FunctionSelector{
          function: nil,
          types: [
            {:tuple, [{:uint, 32}, :bool, {:bytes, 2}]}
          ]
        })
        |> Base.encode16(case: :lower)

      expected_result =
        "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000012040000000000000000000000000000000000000000000000000000000000000"

      assert params == expected_result
    end

    test "encodes dynamic array" do
      params = [[17, 1], true]

      selector = %FunctionSelector{
        function: nil,
        types: [
          {:array, {:uint, 32}},
          :bool
        ]
      }

      result =
        params
        |> TypeEncoder.encode(selector)

      expected_result =
        "00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
        |> Base.decode16!(case: :lower)

      assert result == expected_result

      assert ABI.TypeDecoder.decode(expected_result, selector) == params
    end
  end

  test "example 1 from web3-eth-abi js" do
    value = 0xDF3234
    types = [:bytes]
    params = [value]

    result = TypeEncoder.encode(params, types)

    expected_result =
      "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003df32340000000000000000000000000000000000000000000000000000000000"
      |> Base.decode16!(case: :lower)

    assert expected_result == result

    assert ABI.TypeDecoder.decode(expected_result, types) == [:binary.encode_unsigned(value)]
  end

  test "example 2 from web3-eth-abi js" do
    value1 = 0xDF3234
    value2 = 0xFDFD
    types = [{:array, {:bytes, 32}}]
    params = [[value1, value2]]

    expected_result =
      "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002df32340000000000000000000000000000000000000000000000000000000000fdfd000000000000000000000000000000000000000000000000000000000000"
      |> Base.decode16!(case: :lower)

    result = TypeEncoder.encode(params, types)

    assert expected_result == result

    assert ABI.TypeDecoder.decode(expected_result, types) == [
             [
               <<223, 50, 52, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0>>,
               <<253, 253, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0>>
             ]
           ]
  end

  test "encodes [{:uint, 8}, :string]" do
    types = [{:uint, 8}, :string]
    params = [255, "hello"]

    expected_result =
      "00000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000568656c6c6f000000000000000000000000000000000000000000000000000000"
      |> Base.decode16!(case: :lower)

    result = TypeEncoder.encode(params, types)

    assert expected_result == result

    assert ABI.TypeDecoder.decode(expected_result, types) == params
  end

  test "encodes array of array of strings" do
    types = [{:array, {:array, :string}}]
    params = [[["a", "a"], ["a", "a"]]]

    expected_result =
      "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000016100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000161000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016100000000000000000000000000000000000000000000000000000000000000"
      |> Base.decode16!(case: :lower)

    result = TypeEncoder.encode(params, types)

    assert result == expected_result

    assert TypeDecoder.decode(expected_result, types) == params
  end

  test "omisego example" do
    signature = "(bytes,bytes[],uint256[],bytes[],bytes[])"

    params = [
      {<<248, 150, 1, 248, 66, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 232, 212, 165, 16, 0, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 232, 212, 165, 16, 1, 238, 237, 1, 235, 148, 148, 12,
         8, 212, 224, 238, 174, 45, 103, 83, 223, 64, 131, 190, 128, 70, 233, 153, 153, 168, 148,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 128, 160, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
       [
         <<248, 163, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 248, 92, 237, 1, 235, 148, 148, 12, 8, 212, 224,
           238, 174, 45, 103, 83, 223, 64, 131, 190, 128, 70, 233, 153, 153, 168, 148, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 237, 1, 235, 148, 148, 12, 8, 212,
           224, 238, 174, 45, 103, 83, 223, 64, 131, 190, 128, 70, 233, 153, 153, 168, 148, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 128, 160, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<248, 163, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 248, 92, 237, 1, 235, 148, 148, 12, 8, 212, 224,
           238, 174, 45, 103, 83, 223, 64, 131, 190, 128, 70, 233, 153, 153, 168, 148, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 237, 1, 235, 148, 148, 12, 8, 212,
           224, 238, 174, 45, 103, 83, 223, 64, 131, 190, 128, 70, 233, 153, 153, 168, 148, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 128, 160, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
       ], [1_000_000_000_000, 1_000_000_000_001],
       [
         <<211, 253, 175, 0, 211, 243, 128, 151, 220, 185, 73, 67, 80, 126, 152, 200, 216, 172,
           204, 129, 84, 63, 223, 251, 239, 165, 14, 0, 104, 60, 149, 45, 78, 213, 192, 45, 109,
           72, 200, 147, 36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48,
           88, 204, 41, 121, 105, 12, 62, 58, 98, 28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0,
           245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254, 82, 60, 26, 207, 103,
           220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
           156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105,
           10, 4, 4, 171, 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247,
           120, 88, 30, 111, 183, 142, 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155,
           109, 212, 127, 127, 234, 186, 250, 53, 113, 248, 66, 67, 68, 37, 84, 131, 53, 172, 110,
           105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79, 82, 159, 87,
           131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222,
           156, 68, 111, 171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68,
           227, 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150,
           18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236,
           4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193,
           100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68,
           143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18, 43, 105, 92,
           90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227, 142, 186,
           122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67,
           148, 138, 52, 65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165,
           24, 116, 172, 125, 201, 221, 121, 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46,
           69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50, 165, 106, 58, 112, 7, 162, 208,
           198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84, 186, 233, 24,
           152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232,
           126, 177, 120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84,
           90, 128, 69, 87, 31, 218, 185, 181, 48, 208, 214, 231, 232, 116, 110, 120, 191, 159,
           32, 244, 232, 111, 6>>,
         <<211, 253, 175, 0, 211, 243, 128, 151, 220, 185, 73, 67, 80, 126, 152, 200, 216, 172,
           204, 129, 84, 63, 223, 251, 239, 165, 14, 0, 104, 60, 149, 45, 78, 213, 192, 45, 109,
           72, 200, 147, 36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48,
           88, 204, 41, 121, 105, 12, 62, 58, 98, 28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0,
           245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254, 82, 60, 26, 207, 103,
           220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
           156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105,
           10, 4, 4, 171, 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247,
           120, 88, 30, 111, 183, 142, 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155,
           109, 212, 127, 127, 234, 186, 250, 53, 113, 248, 66, 67, 68, 37, 84, 131, 53, 172, 110,
           105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79, 82, 159, 87,
           131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222,
           156, 68, 111, 171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68,
           227, 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150,
           18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236,
           4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193,
           100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68,
           143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18, 43, 105, 92,
           90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227, 142, 186,
           122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67,
           148, 138, 52, 65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165,
           24, 116, 172, 125, 201, 221, 121, 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46,
           69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50, 165, 106, 58, 112, 7, 162, 208,
           198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84, 186, 233, 24,
           152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232,
           126, 177, 120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84,
           90, 128, 69, 87, 31, 218, 185, 181, 48, 208, 214, 231, 232, 116, 110, 120, 191, 159,
           32, 244, 232, 111, 6>>
       ],
       [
         <<141, 67, 78, 92, 210, 192, 174, 0, 78, 158, 217, 130, 168, 110, 102, 24, 202, 65, 180,
           146, 234, 172, 222, 106, 162, 212, 203, 227, 201, 48, 118, 185, 121, 143, 80, 51, 108,
           178, 34, 221, 43, 205, 145, 55, 194, 168, 27, 82, 146, 127, 206, 215, 195, 216, 138,
           103, 46, 97, 53, 5, 103, 90, 251, 108, 28>>,
         <<141, 67, 78, 92, 210, 192, 174, 0, 78, 158, 217, 130, 168, 110, 102, 24, 202, 65, 180,
           146, 234, 172, 222, 106, 162, 212, 203, 227, 201, 48, 118, 185, 121, 143, 80, 51, 108,
           178, 34, 221, 43, 205, 145, 55, 194, 168, 27, 82, 146, 127, 206, 215, 195, 216, 138,
           103, 46, 97, 53, 5, 103, 90, 251, 108, 28>>
       ]}
    ]

    result = ABI.encode(signature, params)
    assert ABI.decode(signature, result) == params
  end

  defp encode_multiline_string(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.join()
    |> Base.decode16!(case: :mixed)
  end
end
