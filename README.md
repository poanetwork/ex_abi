# ExABI

The [Application Binary Interface](https://solidity.readthedocs.io/en/develop/abi-spec.html) (ABI) of Solidity describes how to transform binary data to types which the Solidity programming language understands. For instance, if we want to call a function `bark(uint32,bool)` on a Solidity-created contract `contract Dog`, what `data` parameter do we pass into our Ethereum transaction? This project allows us to encode such function calls.

## Installation

The latest version (`>= 0.5.0`) of `ex_abi` requires Rust because it uses a Rust NIF for KECCAK-256 hash. You can also try using `0.4.0`, it doesn't have a Rust requirement because it uses a C NIF. But `0.4.0` does not support OTP 23.

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_abi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_abi, "~> 0.5.8"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_abi](https://hexdocs.pm/ex_abi).

## Usage

### Encoding

To encode a function call, pass the ABI spec and the data to pass in to `ABI.encode/1`.

```elixir
iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
<<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, ...>>
```

That transaction can then be sent via JSON-RPC Client [ethereumex](https://github.com/mana-ethereum/ethereumex).


### Decoding

Decode is generally the opposite of encoding, though we generally leave off the function signature from the start of the data. E.g. from above:

```elixir
iex> ABI.decode("baz(uint,address)", "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
[50, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>]
```

### Function selectors

Both `ABI.encode/2` and `ABI.decode/2` can accept a function selector as the first parameter. For example:

``` elixir
selector = %ABI.FunctionSelector{
          function: "startInFlightExit",
          input_names: [
            "inFlightTx",
            "inputTxs",
            "inputUtxosPos",
            "inputTxsInclusionProofs",
            "inFlightTxWitnesses"
          ],
          inputs_indexed: nil,
          method_id: <<90, 82, 133, 20>>,
          returns: [],
          type: :function,
          types: [
            tuple: [
              :bytes,
              {:array, :bytes},
              {:array, {:uint, 256}},
              {:array, :bytes},
              {:array, :bytes}
            ]
          ]
        }

ABI.encode(selector, params)
```

To parse function selector from the abi json, use `ABI.parse_specification/2`:

``` elixir
iex> [%{
...>   "inputs" => [
...>      %{"name" => "_numProposals", "type" => "uint8"}
...>   ],
...>   "payable" => false,
...>   "stateMutability" => "nonpayable",
...>   "type" => "constructor"
...> }]
...> |> ABI.parse_specification
[%ABI.FunctionSelector{function: nil, input_names: ["_numProposals"], inputs_indexed: nil, method_id: <<99, 53, 230, 34>>, returns: [], type: :constructor, types: [uint: 8]}]
```

#### Decoding output

By default, decode and encode functions try to decode/encode input (params that passed to the function). To decode/encode output pass `:output` as the third parameter:

``` elixir
      selector = %FunctionSelector{
        function: "getVersion",
        input_names: [],
        inputs_indexed: nil,
        method_id: <<13, 142, 110, 44>>,
        returns: [:string],
        type: :function,
        types: []
      }

      data =
        "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"
        |> Base.decode16!(case: :lower)

      expected_result = ["1.0.4+a69c763"]

      assert expected_result == ABI.decode(selector, data, :output)
      assert data == ABI.encode(selector, expected_result, :output)
```


## Support

Currently supports:

  * [X] `uint<M>`
  * [X] `int<M>`
  * [X] `address`
  * [X] `uint`
  * [X] `int`
  * [X] `bool`
  * [X] `fixed<M>x<N>`
  * [X] `ufixed<M>x<N>`
  * [X] `fixed`
  * [X] `bytes<M>`
  * [X] `<type>[M]`
  * [X] `bytes`
  * [X] `string`
  * [X] `<type>[]`
  * [X] `(T1,T2,...,Tn)`

# Docs

* [Solidity ABI](https://solidity.readthedocs.io/en/develop/abi-spec.html)
* [Solidity Docs](https://solidity.readthedocs.io/)
