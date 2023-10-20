# Changelog

## 0.6.2
* Add return_names to the FunctionSelector struct (https://github.com/poanetwork/ex_abi/pull/151)
## 0.6.2
* Update ex_keccak to 0.7.3 (https://github.com/poanetwork/ex_abi/pull/146)
## 0.6.1
* Support the enum solidity type (https://github.com/poanetwork/ex_abi/pull/135)
* Use `Logger.warning` instead of `Logger.warn` (https://github.com/poanetwork/ex_abi/pull/144)
## 0.6.0
* Use precompiled version of ex_keccak NIF (https://github.com/poanetwork/ex_abi/pull/127)

Rust is not required anymore

## 0.5.16
* Handle Events with the same hash properly (https://github.com/poanetwork/ex_abi/pull/115)
## 0.5.15
* Fix case typo in nonpayable state mutability (https://github.com/poanetwork/ex_abi/pull/113)
## 0.5.14
* Add state_mutability to ABI.FunctionSelector (https://github.com/poanetwork/ex_abi/pull/109)
* Fix dialyzer, credo warnings (https://github.com/poanetwork/ex_abi/pull/110)
## 0.5.13
* Update jason to 1.4.0 (https://github.com/poanetwork/ex_abi/pull/107)
## 0.5.12
* Update ex_keccak to 0.6.0 (https://github.com/poanetwork/ex_abi/pull/105)
## 0.5.11
* Update ex_keccak to 0.4.0 (https://github.com/poanetwork/ex_abi/pull/92)
## 0.5.10
* Support parsing of multidimensional tuples in specs (https://github.com/poanetwork/ex_abi/pull/89)
## 0.5.9
* Update jason from 1.2.0 to 1.3.0
* Update ex_keccak from 0.2.2 to 0.3.0
## 0.5.8
* Allow to encode lists for tuple types (https://github.com/poanetwork/ex_abi/pull/72)
## 0.5.7
* Support error types (https://github.com/poanetwork/ex_abi/pull/69)
## 0.5.6
* Bump ex_keccak version (https://github.com/poanetwork/ex_abi/pull/67)
## 0.5.5
* Support decoding of output without method_id prefix (https://github.com/poanetwork/ex_abi/pull/61)
## 0.5.4
* Bump ex_keccak (otp 24 support) (https://github.com/poanetwork/ex_abi/pull/59)
## 0.5.3
* Fix decoding of output data prefixed with method id (https://github.com/poanetwork/ex_abi/pull/50)
## 0.5.2
* Fix parsing of function selectors (https://github.com/poanetwork/ex_abi/pull/47)
## 0.5.1
* Chore: bump `ex_keccak` version (https://github.com/poanetwork/ex_abi/pull/43)
## 0.5.0
* Add `ex_keccak` library because `keccakf1600` doesn't support otp 23. Now Rust is required (https://github.com/poanetwork/ex_abi/pull/42)
## 0.4.0
* Fix encoding and decoding of dynamic types (https://github.com/poanetwork/ex_abi/pull/34)
* Allow to decoded function outputs (https://github.com/poanetwork/ex_abi/pull/36)
* Parse array of tuples in the specification (https://github.com/poanetwork/ex_abi/pull/37)
## 0.3.2
* Fix array/tuple decoding (https://github.com/poanetwork/ex_abi/pull/32)
## 0.3.1
* ABI parsing tuple type (https://github.com/poanetwork/ex_abi/pull/29)
* ABI encoding array type fix (https://github.com/poanetwork/ex_abi/pull/28)
* Elixir version bump: 1.10.2 (https://github.com/poanetwork/ex_abi/pull/27)
## 0.3.0
* Fix encoding/decoding of dynamic size types (https://github.com/poanetwork/ex_abi/pull/24)
## 0.2.2
* Add support for constructor selectors (https://github.com/poanetwork/ex_abi/pull/21)
## 0.2.1
* Dialyzer fixes (https://github.com/poanetwork/ex_abi/pull/18)
## 0.2.0
* Fix decoding array types (https://github.com/poanetwork/ex_abi/pull/14)
## 0.1.18
* Add event parsing (https://github.com/poanetwork/ex_abi/pull/11)
## 0.1.17
* Attach the method id to the struct as `method_id` (https://github.com/poanetwork/ex_abi/pull/9)
* Add the argument names to the struct as `input_names` (https://github.com/poanetwork/ex_abi/pull/9)
* Add `encode_type/1` to give a public API for encoding single types (used for display in blockscout) (https://github.com/poanetwork/ex_abi/pull/9)
* Add `find_and_decode/2` which finds the correct function selector from the list by method_id and decodes the provided call (https://github.com/poanetwork/ex_abi/pull/9)
## 0.1.16
* Allow functions to have multiple output types (https://github.com/poanetwork/ex_abi/pull/8)
## 0.1.15
* Add support for tuple type for inputs and outputs (https://github.com/poanetwork/ex_abi/pull/6)
* Fix support for fixed-length arrays (https://github.com/poanetwork/ex_abi/pull/7)
## 0.1.14
* Fix handling of decoding data with dynamic types (https://github.com/poanetwork/ex_abi/pull/5)
## 0.1.13
* Add `int` support (https://github.com/poanetwork/ex_abi/pull/3)
## 0.1.12
* Fix `string` decoding to truncate on encountering NUL
* Fix some edge-cases in `tuple` encoding/decoding
## 0.1.11
* Add support for method ID calculation of all standard types
## 0.1.10
* Fix parsing of function names containing uppercase letters/digits/underscores
* Add support for `bytes<M>`
## 0.1.9
* Add support for parsing ABI specification documents (`.abi.json` files)
* Reimplement function signature parsing using a BNF grammar
* Fix potential stack overflow during encoding/decoding
## 0.1.8
* Fix ordering of elements in tuples
## 0.1.7
* Fix support for arrays of uint types
## 0.1.6
* Add public interface to raw function versions.
## 0.1.5
* Bugfix so that addresses are still left padded.
## 0.1.4
* Bugfix for tuples to properly handle tail pointer position.
## 0.1.3
* Bugfix for tuples to properly handle head/tail encoding
## 0.1.2
* Add support for tuples, fixed-length and variable length arrays
