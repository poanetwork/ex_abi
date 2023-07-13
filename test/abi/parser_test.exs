defmodule ABI.ParserTest do
  use ExUnit.Case, async: true

  doctest ABI.Parser
  alias ABI.Parser

  describe "parse" do
    test "successfully parses signatures" do
      assert %ABI.FunctionSelector{
               function: "simple",
               method_id: nil,
               type: nil,
               inputs_indexed: nil,
               state_mutability: nil,
               input_names: [],
               types: [uint: 256],
               returns: []
             } = Parser.parse!("simple(uint256)")

      assert %ABI.FunctionSelector{
               function: "execTransaction",
               input_names: [],
               inputs_indexed: nil,
               method_id: nil,
               returns: [],
               state_mutability: nil,
               type: nil,
               types: [
                 :address,
                 {:uint, 256},
                 :bytes,
                 {:uint, 8},
                 {:uint, 256},
                 {:uint, 256},
                 {:uint, 256},
                 :address,
                 :address,
                 :bytes
               ]
             } =
               Parser.parse!(
                 "execTransaction(address,uint256,bytes,enum,uint256,uint256,uint256,address,address,bytes)"
               )
    end
  end
end
