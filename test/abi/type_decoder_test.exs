defmodule ABI.TypeDecoderTest do
  use ExUnit.Case, async: true
  doctest ABI.TypeDecoder

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
end
