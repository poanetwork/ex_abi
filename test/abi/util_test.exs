defmodule ABI.UtilTest do
  use ExUnit.Case, async: true

  @selectors [
    %ABI.FunctionSelector{
      function: "Transfer",
      method_id: <<221, 242, 82, 173>>,
      type: :event,
      inputs_indexed: [false, false, false],
      state_mutability: nil,
      input_names: ["from", "to", "tokenId"],
      types: [:address, :address, {:uint, 256}],
      returns: []
    },
    %ABI.FunctionSelector{
      function: "Transfer",
      method_id: <<221, 242, 82, 173>>,
      type: :event,
      inputs_indexed: [true, true, true],
      state_mutability: nil,
      input_names: ["from", "to", "tokenId"],
      types: [:address, :address, {:uint, 256}],
      returns: []
    }
  ]

  describe "decode events" do
    test "successfully decodes ERC721 transfer event" do
      {:ok, selector} =
        ABI.Util.find_selector_by_event_id(@selectors, <<221, 242, 82, 173>>, [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 230, 218, 29, 25, 253, 206, 193, 121, 186, 151,
            85, 242, 198, 19, 159, 143, 254, 203, 254, 176>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 168, 47, 182, 247, 249, 220, 207, 188, 171, 157,
            153, 173, 222, 184, 132, 3, 58, 241, 27, 134>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 12, 12>>
        ])

      assert selector.function == "Transfer"
      assert selector.inputs_indexed == [true, true, true]
    end
  end
end
