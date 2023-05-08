object "ERC1155" {
  code {

    /* ---------- utility functions ---------- */
		function lte(a, b) -> r {
      r := iszero(gt(a, b))
    }

    // Store the creator in slot zero.
    sstore(0, caller())

		let offset := add(0x4c9, 0x20) // first parameter is length of bytecode, this is hardcoded
		let uriDataLength := sub(codesize(), offset) // codesize - offset (maybe we need safeSub here)
   
		codecopy(0, offset, uriDataLength)  // right offset hardcoded

		let uriLength := mload(0)

		sstore(3, uriLength)

		if lte(uriLength, 0x20) {
      let uri := mload(0x20)
      sstore(4, uri)
    }

    if gt(uriLength, 0x20) {
      let wordCount := add(div(sub(uriLength, 1), 0x20), 1)

      for
        { let i := 0 }
        lt(i, wordCount)
        { i:= add(i, 1) }
      {
        sstore(
          add(4, i),
          mload(mul(0x20, add(i, 1)))
        )
      }
		}

    // Deploy the contract
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }
  object "runtime" {
    code {
      // Protection against sending Ether
      require(iszero(callvalue()))

      // Set the memory pointer to point to 0x80 at the beginning
      setMemPtr(add(memPtrPos(), 0x20))

      // Dispatcher
      switch selector()
      case 0x0e89341c /* uri(uint256 id) */ {
        // note: the id is not used here, see this function's docstring
        let from, to := uri()

        returnMemoryData(from, to)
      }
      case 0x731133e9 /* mint(address to, uint256 id, uint256 amount, bytes memory data) */{
        mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))

        // check that the receiving address can receive erc1155s
        _doSafeTransferAcceptanceCheck(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
        
        returnZero()
      }
      case 0x00fdd58e /* balanceOf(address account, uint256 id) */ {
        let account := decodeAsAddress(0)
        let id := decodeAsUint(1)

        returnUint(balanceOf(account, id))
      }
      default {
        revert(0, 0)
      }

      function uri() -> startsAt, endsAt {
        startsAt := getMemPtr()
        let uriLength := sload(uriLengthPos())

        mstore(startsAt, 0x20) // store offset
        mstore(safeAdd(startsAt, 0x20), uriLength) // length

        setMemPtr(safeAdd(startsAt, 0x40))

        if lte(uriLength, 0x20) {
          mstore(getMemPtr(), sload(add(uriLengthPos(), 1))) // data
          incrPtr()
        }

        if gt(uriLength, 0x20) {
          let wordCount := add(div(sub(uriLength, 1), 0x20), 1)

          for
            { let i := 0 }
            lt(i, wordCount)
            { i:= add(i, 1) }
          {
            let chunk_i := sload(add(4, i))
            mstore(getMemPtr(), chunk_i) // let's put it into memory
            incrPtr() // ptr++
          }
        }

        endsAt := getMemPtr()
      }

      function mint(to, id, amount) {
        let toBalanceSlot := balances(to, id)
        let toBalance := sload(toBalanceSlot)
        let toNewBalance := safeAdd(toBalance, amount)
        sstore(toBalanceSlot, toNewBalance)

        emitTransferSingle(caller(), address0(), to, id, amount)
      }

      function _doSafeTransferAcceptanceCheck(account, id, amount) {
        // 0xf23a6e61 = onERC1155Received(address,address,uint256,uint256,bytes)
        let fnSelector := 0xf23a6e6100000000000000000000000000000000000000000000000000000000

        if eq(extcodesize(account), 0) { leave } // receiver is not a contract

        mstore(0, 0)

        mstore(getMemPtr(), fnSelector)
        mstore(add(getMemPtr(), 0x04), address())
        mstore(add(getMemPtr(), 0x24), 0x0000000000000000000000000000000000000000000000000000000000000000)
        mstore(add(getMemPtr(), 0x44), id)
        mstore(add(getMemPtr(), 0x64), amount)
        mstore(add(getMemPtr(), 0x84), 0x00000000000000000000000000000000000000000000000000000000000000a0)
        mstore(add(getMemPtr(), 0xa4), 0x0000000000000000000000000000000000000000000000000000000000000000)

        let success := call(gas(), account, 0, getMemPtr(), 0xc4, 0x00, 0x04)
        require(success)

        let response := mload(0)
        require(eq(response, fnSelector))
      }

      function balanceOf(account, id) -> b {
        b := sload(balances(account, id))
      }

      /* ---------- calldata decoding functions ----------- */
      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function decodeAsAddress(offset) -> v {
        v := decodeAsUint(offset)
        if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
          revert(0, 0)
        }
      }

      function decodeAsSelector(value) -> s {
        s := div(value, 0x100000000000000000000000000000000000000000000000000000000)
      }

      function decodeAsUint(offset) -> v {
        let pos := add(4, mul(offset, 0x20))
        if lt(calldatasize(), add(pos, 0x20)) {
          revert(0, 0)
        }
        v := calldataload(pos)
      }

      /* ---------- calldata encoding functions ---------- */
      function returnUint(v) {
        mstore(0, v)
        return(0, 0x20)
      }

      function returnZero() {
        mstore(0, 0)
        return(0, 0)
      }

      function returnTrue() {
        returnUint(1)
      }

      function returnMemoryData(from, to) {
        return(from, to)
      }

      /* -------- events ---------- */
      function emitTransferSingle(operator, from, to, id, amount) {
        let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
        // store the non-indexed data in memory to emit
        mstore(0x00, id)
        mstore(0x20, amount)

        log4(0x00, 0x40, signatureHash, operator, from, to)
      }

      /* -------- storage layout ---------- */
      function ownerPos() -> p { p := 0 }
      function balancesPos() -> p { p := 1 }
      function operatorApprovalsPos() -> p { p := 2 }
      function uriLengthPos() -> p { p := 3 }

      /* -------- storage access ---------- */
      function owner() -> o {
        o := sload(ownerPos())
      }

      function balances(account, id) -> b {
        // key = <balanceSlot><address><id>
        // slot = keccak256(key)
        mstore(0x00, balancesPos()) // use scratch space for hashing
        mstore(0x20, account)
        mstore(0x40, id)
        b := keccak256(0x00, 0x60)
      }

      /* ---------- free memory pointer ---------- */
      function memPtrPos() -> p { p := 0x60 } // where is the memory pointer itself stored in memory
      function getMemPtr() -> p { p := mload(memPtrPos()) }
      function setMemPtr(v) { mstore(memPtrPos(), v) }
      function incrPtr() { mstore(memPtrPos(), safeAdd(getMemPtr(), 0x20)) } // ptr++

      /* ---------- utility functions ---------- */
      function lte(a, b) -> r {
        r := iszero(gt(a, b))
      }
      function gte(a, b) -> r {
        r := iszero(lt(a, b))
      }
      function safeAdd(a, b) -> r {
        r := add(a, b)
        if or(lt(r, a), lt(r, b)) { revert(0, 0) }
      }
      function revertIfZeroAddress(addr) {
        require(addr)
      }
      function address0() -> a {
        a := 0x0000000000000000000000000000000000000000000000000000000000000000
      }
      function require(condition) {
        if iszero(condition) { revert(0, 0) }
      }
    }
  }
}