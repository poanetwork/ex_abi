# 0.3.1
* ABI parsing tuple type (https://github.com/poanetwork/ex_abi/pull/29)
* ABI encoding array type fix (https://github.com/poanetwork/ex_abi/pull/28)
* Elixir version bump: 1.10.2 (https://github.com/poanetwork/ex_abi/pull/27)
# 0.3.0
* Fix encoding/decoding of dynamic size types (https://github.com/poanetwork/ex_abi/pull/24)
# 0.2.2
* Add support for constructor selectors (https://github.com/poanetwork/ex_abi/pull/21)
# 0.2.1
* Dialyzer fixes (https://github.com/poanetwork/ex_abi/pull/18)
# 0.2.0
* Fix decoding array types (https://github.com/poanetwork/ex_abi/pull/14)
# 0.1.18
* Add event parsing (https://github.com/poanetwork/ex_abi/pull/11)
# 0.1.17
* Attach the method id to the struct as `method_id` (https://github.com/poanetwork/ex_abi/pull/9)
* Add the argument names to the struct as `input_names` (https://github.com/poanetwork/ex_abi/pull/9)
* Add `encode_type/1` to give a public API for encoding single types (used for display in blockscout) (https://github.com/poanetwork/ex_abi/pull/9)
* Add `find_and_decode/2` which finds the correct function selector from the list by method_id and decodes the provided call (https://github.com/poanetwork/ex_abi/pull/9)
# 0.1.16
* Allow functions to have mutliple output types (https://github.com/poanetwork/ex_abi/pull/8)
# 0.1.15
* Add support for tuple type for inputs and outputs (https://github.com/poanetwork/ex_abi/pull/6)
* Fix support for fixed-length arrays (https://github.com/poanetwork/ex_abi/pull/7)
# 0.1.14
* Fix handling of decoding data with dynamic types (https://github.com/poanetwork/ex_abi/pull/5)
# 0.1.13
* Add `int` support (https://github.com/poanetwork/ex_abi/pull/3)
# 0.1.12
* Fix `string` decoding to truncate on encountering NUL
* Fix some edge-cases in `tuple` encoding/decoding
# 0.1.11
* Add support for method ID calculation of all standard types
# 0.1.10
* Fix parsing of function names containing uppercase letters/digits/underscores
* Add support for `bytes<M>`
# 0.1.9
* Add support for parsing ABI specification documents (`.abi.json` files)
* Reimplement function signature parsing using a BNF grammar
* Fix potential stack overflow during encoding/decoding
# 0.1.8
* Fix ordering of elements in tuples
# 0.1.7
* Fix support for arrays of uint types
# 0.1.6
* Add public interface to raw function versions.
# 0.1.5
* Bugfix so that addresses are still left padded.
# 0.1.4
* Bugfix for tuples to properly handle tail pointer poisition.
# 0.1.3
* Bugfix for tuples to properly handle head/tail encoding
# 0.1.2
* Add support for tuples, fixed-length and variable length arrays
