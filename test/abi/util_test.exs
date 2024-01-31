defmodule ABI.UtilTest do
  use ExUnit.Case, async: true

  @selectors [
    %ABI.FunctionSelector{
      function: "Transfer",
      method_id:
        <<221, 242, 82, 173, 27, 226, 200, 155, 105, 194, 176, 104, 252, 55, 141, 170, 149, 43,
          167, 241, 99, 196, 161, 22, 40, 245, 90, 77, 245, 35, 179, 239>>,
      type: :event,
      inputs_indexed: [false, false, false],
      state_mutability: nil,
      input_names: ["from", "to", "tokenId"],
      types: [:address, :address, {:uint, 256}],
      returns: []
    },
    %ABI.FunctionSelector{
      function: "Transfer",
      method_id:
        <<221, 242, 82, 173, 27, 226, 200, 155, 105, 194, 176, 104, 252, 55, 141, 170, 149, 43,
          167, 241, 99, 196, 161, 22, 40, 245, 90, 77, 245, 35, 179, 239>>,
      type: :event,
      inputs_indexed: [true, true, true],
      state_mutability: nil,
      input_names: ["from", "to", "tokenId"],
      types: [:address, :address, {:uint, 256}],
      returns: []
    },
    %ABI.FunctionSelector{
      function: "OwnershipTransferred",
      method_id:
        <<139, 224, 7, 156, 83, 22, 89, 20, 19, 68, 205, 31, 208, 164, 242, 132, 25, 73, 127, 151,
          34, 163, 218, 175, 227, 180, 24, 111, 107, 100, 87, 224>>,
      type: :event,
      inputs_indexed: [true, true],
      state_mutability: nil,
      input_names: ["previousOwner", "newOwner"],
      types: [:address, :address],
      returns: []
    }
  ]

  describe "decode events" do
    test "successfully decodes ERC721 transfer event" do
      {:ok, selector} =
        ABI.Util.find_selector_by_event_id(
          @selectors,
          <<221, 242, 82, 173, 27, 226, 200, 155, 105, 194, 176, 104, 252, 55, 141, 170, 149, 43,
            167, 241, 99, 196, 161, 22, 40, 245, 90, 77, 245, 35, 179, 239>>,
          [
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 230, 218, 29, 25, 253, 206, 193, 121, 186, 151,
              85, 242, 198, 19, 159, 143, 254, 203, 254, 176>>,
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 168, 47, 182, 247, 249, 220, 207, 188, 171, 157,
              153, 173, 222, 184, 132, 3, 58, 241, 27, 134>>,
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 12, 12>>
          ]
        )

      assert selector.function == "Transfer"
      assert selector.inputs_indexed == [true, true, true]
    end

    test "decode OwnershipTransferred event" do
      {:ok, selector} =
        ABI.Util.find_selector_by_event_id(
          @selectors,
          <<139, 224, 7, 156, 83, 22, 89, 20, 19, 68, 205, 31, 208, 164, 242, 132, 25, 73, 127,
            151, 34, 163, 218, 175, 227, 180, 24, 111, 107, 100, 87, 224>>,
          [
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0>>,
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 79, 181, 74, 58, 157, 2, 63, 219, 87, 69, 216,
              158, 228, 106, 170, 82, 18, 171, 87, 125>>,
            nil
          ]
        )

      assert selector.function == "OwnershipTransferred"
      assert selector.inputs_indexed == [true, true]
    end
  end
end
