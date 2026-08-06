defmodule ABI.EventTest do
  use ExUnit.Case, async: true

  doctest ABI.Event

  alias ABI.Event
  alias ABI.FunctionSelector

  describe "find_and_decode/6" do
    # Regression test for an event whose non-indexed argument is a struct
    # (tuple) containing a Solidity `function` pointer. The `function` type is a
    # 24-byte value (20-byte address + 4-byte selector), stored right-padded in
    # one 32-byte word, exactly like `bytes24`.
    #
    # event ActionLogged((uint256 id, function (uint256) external callback) action)
    test "decodes a non-indexed tuple containing a `function` component" do
      abi = [
        %{
          "anonymous" => false,
          "name" => "ActionLogged",
          "type" => "event",
          "inputs" => [
            %{
              "indexed" => false,
              "internalType" => "struct StructWithFunctionEvent.Action",
              "name" => "action",
              "type" => "tuple",
              "components" => [
                %{"internalType" => "uint256", "name" => "id", "type" => "uint256"},
                %{
                  "internalType" => "function (uint256) external",
                  "name" => "callback",
                  "type" => "function"
                }
              ]
            }
          ]
        }
      ]

      selectors = ABI.parse_specification(abi, include_events?: true)

      # The event must survive parsing (previously it was silently dropped).
      assert [%FunctionSelector{types: [{:tuple, [{:uint, 256}, :function]}]}] = selectors

      # 20-byte address ++ 4-byte selector == the decoded `function` value.
      function_value =
        Base.decode16!("29088eeb3082c897bebd16bbafc162322cbb1bf47cfdab90", case: :lower)

      # keccak256("ActionLogged((uint256,function))")
      topic1 =
        Base.decode16!(
          "413ec73c547fcf364943e3f9182965c6662c9bb75c94568d39ebb9f66d2cff4b",
          case: :lower
        )

      # ABI-encoded tuple: word 1 = id (1337), word 2 = function value right-padded.
      data = <<1337::256>> <> function_value <> <<0::64>>

      {selector, event_values} = Event.find_and_decode(selectors, topic1, nil, nil, nil, data)

      assert selector.function == "ActionLogged"
      assert selector.method_id == topic1

      assert event_values == [
               {"action", "(uint256,function)", false, {1337, function_value}}
             ]
    end
  end
end
