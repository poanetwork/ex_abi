defmodule ABI.TypeDecoderTest do
  use ExUnit.Case, async: true

  doctest ABI.TypeDecoder

  alias ABI.TypeDecoder

  describe "decode/2 '{:int, size}' type" do
    test "successfully decodes positives and negatives integers" do
      positive_int = "000000000000000000000000000000000000000000000000000000000000002a"
      negative_int = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8f1"
      result_to_decode = Base.decode16!(positive_int <> negative_int, case: :lower)
      selector = %ABI.FunctionSelector{
        function: "baz",
        types: [
          {:int, 8},
          {:int, 256}
        ],
        returns: :int
      }

      assert ABI.TypeDecoder.decode(result_to_decode, selector) == [42, -9999]
    end
  end

  describe "decode_raw" do
    test "with string data" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000004
        6461766500000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [:string]) == ["dave"]
    end

    test "with array data" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000020
        0000000000000000000000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [{:array, :address}]) == [[]]

      data =
         """
         0000000000000000000000000000000000000000000000000000000000000020
         0000000000000000000000000000000000000000000000000000000000000001
         0000000000000000000000000000000000000000000000000000000000000123
         """
         |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [{:array, {:uint, 256}}]) == [[0x123]]
    end

    test "with multiple types" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        0000000000000000000000000000000000000000000000000000000000000080
        3132333435363738393000000000000000000000000000000000000000000000
        00000000000000000000000000000000000000000000000000000000000000e0
        0000000000000000000000000000000000000000000000000000000000000002
        0000000000000000000000000000000000000000000000000000000000000456
        0000000000000000000000000000000000000000000000000000000000000789
        000000000000000000000000000000000000000000000000000000000000000d
        48656c6c6f2c20776f726c642100000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [{:uint, 256}, {:array, {:uint, 32}}, {:bytes, 10}, :bytes]) ==
        [0x123, [0x456, 0x789], "1234567890", "Hello, world!"]
    end

    test "with static tuple" do
      data =
        """
        0000000000000000000000000000000000000000000000000000000000000123
        3132333435363738393000000000000000000000000000000000000000000000
        """
        |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [{:tuple, [{:uint, 256}, {:bytes, 10}]}]) == [{0x123, "1234567890"}]
    end

    test "with dynamic tuple" do
      data =
         """
         0000000000000000000000000000000000000000000000000000000000000020
         0000000000000000000000000000000000000000000000000000000000000080
         0000000000000000000000000000000000000000000000000000000000000123
         00000000000000000000000000000000000000000000000000000000000000c0
         0000000000000000000000000000000000000000000000000000000000000004
         6461766500000000000000000000000000000000000000000000000000000000
         000000000000000000000000000000000000000000000000000000000000000d
         48656c6c6f2c20776f726c642100000000000000000000000000000000000000
         """
         |> encode_multiline_string()

      assert TypeDecoder.decode_raw(data, [{:tuple, [:bytes, {:uint, 256}, :string]}]) ==
        [{"dave", 0x123, "Hello, world!"}]
    end
  end

  defp encode_multiline_string(data) do
    data
    |> String.split("\n", trim: true)
    |> Enum.join()
    |> Base.decode16!(case: :mixed)
  end
end
