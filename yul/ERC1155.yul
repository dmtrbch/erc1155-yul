object "ERC1155" {
  code {

    /* ---------- utility functions ---------- */
		function lte(a, b) -> r {
      r := iszero(gt(a, b))
    }
    function safeSub(a, b) -> r {
      r := sub(a, b)
      if gt(r, a) { revert(0, 0) }
    }

		let offset := add(0xea3, 0x20) // first parameter is length of bytecode, this is hardcoded
		let uriDataLength := safeSub(codesize(), offset) // codesize - offset (maybe we need safeSub here)
   
		codecopy(0, offset, uriDataLength)  // right offset hardcoded

		let uriLength := mload(0)

		sstore(2, uriLength)

		if lte(uriLength, 0x20) {
      let uri := mload(0x20)
      sstore(3, uri)
    }

    if gt(uriLength, 0x20) {
      let wordCount := add(div(sub(uriLength, 1), 0x20), 1)

      for
        { let i := 0 }
        lt(i, wordCount)
        { i:= add(i, 1) }
      {
        sstore(
          add(3, i),
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
      case 0x01ffc9a7 /* "supportsInterface(bytes4 interfaceId)" */ {
        let interfaceId := calldataload(0x04)

        let IERC1155InterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
        let IERC1155MetdataURIInterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
        let IERC165InterfaceId := 0x01ffc9a700000000000000000000000000000000000000000000000000000000
        
        returnUint(or(eq(interfaceId, IERC1155InterfaceId), or(eq(interfaceId, IERC1155MetdataURIInterfaceId), eq(interfaceId, IERC165InterfaceId))))
      }
      case 0x0e89341c /* uri(uint256 id) */ {
        // note: the id is not used here
        let from, to := uri()

        returnMemoryData(from, to)
      }
      case 0x00fdd58e /* balanceOf(address account, uint256 id) */ {
        let account := decodeAsAddress(0)
        let id := decodeAsUint(1)

        returnUint(balanceOf(account, id))
      }
      case 0x4e1273f4 /* balanceOfBatch(address[] memory accounts, uint256[] memory ids) */ {
        let accountsOffsest := decodeAsAddress(0)
        let idsOffset := decodeAsUint(1)
        
        let from, to := balanceOfBatch(accountsOffsest, idsOffset)

        returnMemoryData(from, to)
      }
      case 0xa22cb465 /* "setApprovalForAll(address operator, bool approved)" */ {
        setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
      }
      case 0xe985e9c5 /* "isApprovedForAll(address account, address operator)" */ {
        let approved := isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1))
        returnUint(approved)
      }
      case 0xf242432a /* "safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)" */ {
        let from := decodeAsAddress(0)
        let to := decodeAsAddress(1)
        let id := decodeAsAddress(2)
        let amount := decodeAsAddress(3)

        safeTransferFrom(from, to, id, amount)
      
        emitTransferSingle(caller(), from, to, id, amount)

        // check that the receiving address can receive erc1155 tokens
        _doSafeTransferAcceptanceCheck(from, to, id, amount)
      }
      case 0x2eb2c2d6 /* "safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)" */ {
        let from := decodeAsAddress(0)
        let to := decodeAsAddress(1)
        let idsOffset := decodeAsUint(2)
        let amountsOffset := decodeAsUint(3)
        let dataOffset := decodeAsUint(4)

        safeBatchTransferFrom(from, to, idsOffset, amountsOffset)
      
        emitTransferBatch(caller(), from, to, idsOffset, amountsOffset)

        // check that the receiving address can receive erc1155 tokens
        _doSafeBatchTransferAcceptanceCheck(from, to, idsOffset, amountsOffset, dataOffset, 0)
      }
      case 0x02fe5305 /* setURI(string memory newuri) */ {
        setURI(decodeAsUint(0))
      }
      case 0x731133e9 /* mint(address to, uint256 id, uint256 amount, bytes memory data) */{
        let to := decodeAsAddress(0)
        let id := decodeAsUint(1)
        let amount := decodeAsUint(2)

        mint(to, id, amount)

        emitTransferSingle(caller(), address0(), to, id, amount)

        // check that the receiving address can receive erc1155 tokens
        _doSafeTransferAcceptanceCheck(address0(), to, id, amount)
      }
      case 0x1f7fdffa /* mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) */ {
        let to := decodeAsAddress(0)
        let idsOffset := decodeAsUint(1)
        let amountsOffset := decodeAsUint(2)
        let dataOffset := decodeAsUint(3)
        
        mintBatch(to, idsOffset, amountsOffset)
      
        emitTransferBatch(caller(), address0(), to, idsOffset, amountsOffset)

        // check that the receiving address can receive erc1155 tokens
        _doSafeBatchTransferAcceptanceCheck(address0(), to, idsOffset, amountsOffset, dataOffset, 1)
      }
      case 0xf5298aca /* burn(address from, uint256 id, uint256 amount) */ {
        let from := decodeAsAddress(0)
        let id := decodeAsUint(1)
        let amount := decodeAsUint(2)

        burn(from, id, amount)

        emitTransferSingle(caller(), from, address0(), id, amount)
      }
      case 0x6b20c454 /* burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) */ {
        let from := decodeAsAddress(0)
        let idsOffset := decodeAsUint(1)
        let amountsOffset := decodeAsUint(2)

        burnBatch(from, idsOffset, amountsOffset)

        emitTransferBatch(caller(), from, address0(), idsOffset, amountsOffset)
      }
      default {
        revert(0, 0)
      }

      /* ---------- implementation functions ---------- */
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
            let chunk := sload(add(3, i))
            mstore(getMemPtr(), chunk) // let's put it into memory
            incrPtr() // ptr++
          }
        }

        endsAt := getMemPtr()
      }

      function balanceOf(account, id) -> b {
        b := sload(balances(account, id))
      }

      function balanceOfBatch(_accountsOffset, _idsOffset) -> startsAt, endsAt {
        let accountsLength := decodeAsArrayLength(_accountsOffset)
        let idsLength := decodeAsArrayLength(_idsOffset)

        require(eq(idsLength, accountsLength))

        startsAt := getMemPtr()
        mstore(startsAt, 0x20)
        mstore(safeAdd(startsAt, 0x20), accountsLength)
        
        setMemPtr(safeAdd(startsAt, 0x40))

        let idsPtr := add(_idsOffset, 0x24)
        let accountsPtr := add(_accountsOffset, 0x24)

        for 
          { let i := 0 }
          lt(i, accountsLength)
          { i := add(i, 1) }
        {
          let _account := calldataload(add(accountsPtr, mul(0x20, i)))
          let _id := calldataload(add(idsPtr, mul(0x20, i)))
          let memLocation := getMemPtr()

          mstore(memLocation, balanceOf(_account, _id))
          incrPtr()
        }
        endsAt := getMemPtr()
      }

      function setApprovalForAll(operator, approved) {
        let _owner := caller()
        require(iszero(eq(_owner, operator)))

        let offset := operatorApprovals(_owner, operator)
        sstore(offset, approved)

        emitApprovalForAll(_owner, operator, approved)
      }

      function isApprovedForAll(account, operator) -> v {
        let offset := operatorApprovals(account, operator)
        v := sload(offset)
      }

      function safeTransferFrom(_from, _to, _id, _amount) {
        // ERC1155: caller is not token owner or approved
        require(or(eq(_from, caller()), isApprovedForAll(_from, caller())))

        let fromBalance := balanceOf(_from, _id)

        require(lte(_amount, fromBalance))
        
        let fromOffset := balances(_from, _id)
        sstore(fromOffset, sub(fromBalance, _amount))

        let toOffset := balances(_to, _id)
        let toBalance := balanceOf(_to, _id)
        sstore(toOffset, safeAdd(toBalance, _amount))
      }

      function safeBatchTransferFrom(_from, _to, _idsOffset, _amountsOffset) {
        // ERC1155: caller is not token owner or approved
        require(or(eq(_from, caller()), isApprovedForAll(_from, caller())))

        let idsLength := decodeAsArrayLength(_idsOffset)
        let amountsLength := decodeAsArrayLength(_amountsOffset)

        require(eq(idsLength, amountsLength))

        let idsPtr := add(_idsOffset, 0x24)
        let amountsPtr := add(_amountsOffset, 0x24)

        for
          { let i := 0 }
          lt(i, idsLength)
          { i := add(i, 1) }
        {
          let _id := calldataload(add(idsPtr, mul(0x20, i)))
          let _amount := calldataload(add(amountsPtr, mul(0x20, i)))

          let fromBalance := balanceOf(_from, _id)

          require(lte(_amount, fromBalance))

          let fromOffset := balances(_from, _id)
          sstore(fromOffset, sub(fromBalance, _amount))

          let toOffset := balances(_to, _id)
          let toBalance := balanceOf(_to, _id)
          sstore(toOffset, safeAdd(toBalance, _amount))
        }
      }

      function setURI(uriOffset) {
        // reset old uri data
        let oldUriLength := sload(uriLengthPos())

        if lte(oldUriLength, 0x20) {
          sstore(3, 0) //string position starts in slot 3
        }

        if gt(oldUriLength, 0x20) {
          let wordCount := add(div(sub(oldUriLength, 1), 0x20), 1)

          for
            { let i := 0 }
            lt(i, wordCount)
            { i:= add(i, 1) }
          {
            sstore(add(3, i), 0)
          }
		    }

        // new uri data
        let uriLength := decodeAsArrayLength(uriOffset)
        let uriPtr := add(uriOffset, 0x24)

		    sstore(2, uriLength)

		    if lte(uriLength, 0x20) {
          let _uri := calldataload(uriPtr)
          sstore(3, _uri)
        }

        if gt(uriLength, 0x20) {
          let wordCount := add(div(sub(uriLength, 1), 0x20), 1)

          for
            { let i := 0 }
            lt(i, wordCount)
            { i:= add(i, 1) }
          {
            sstore(
              add(3, i),
              calldataload(add(uriPtr, mul(0x20, i)))
            )
          }
		    }
      }

      function mint(to, id, amount) {
        let toBalanceSlot := balances(to, id)
        let toBalance := sload(toBalanceSlot)
        let toNewBalance := safeAdd(toBalance, amount)
 
        sstore(toBalanceSlot, toNewBalance)
      }

      function mintBatch(_to, _idsOffset, _amountsOffset) {
        let idsLength := decodeAsArrayLength(_idsOffset)
        let amountsLength := decodeAsArrayLength(_amountsOffset)

        require(eq(idsLength, amountsLength))

        let idsPtr := add(_idsOffset, 0x24)
        let amountsPtr := add(_amountsOffset, 0x24)

        for
          { let i := 0 }
          lt(i, idsLength)
          { i := add(i, 1) }
        {
          let _id := calldataload(add(idsPtr, mul(0x20, i)))
          let _amount := calldataload(add(amountsPtr, mul(0x20, i)))
          mint(_to, _id, _amount)
        }
      }

      function burn(_from, _id, _amount) {
        let fromBalance := balanceOf(_from, _id)

        require(lte(_amount, fromBalance))

        let fromOffset := balances(_from, _id)
        sstore(fromOffset, sub(fromBalance, _amount))
      }

      function burnBatch(_from, _idsOffset, _amountsOffset) {
        let idsLength := decodeAsArrayLength(_idsOffset)
        let amountsLength := decodeAsArrayLength(_amountsOffset)

        require(eq(idsLength, amountsLength))

        let idsPtr := add(_idsOffset, 0x24)
        let amountsPtr := add(_amountsOffset, 0x24)

        for
          { let i := 0 }
          lt(i, idsLength)
          { i := add(i, 1) }
        {
          let _id := calldataload(add(idsPtr, mul(0x20, i)))
          let _amount := calldataload(add(amountsPtr, mul(0x20, i)))
          burn(_from, _id, _amount)
        }
      }

      function _doSafeTransferAcceptanceCheck(_from, account, id, amount) {
        // 0xf23a6e61 = onERC1155Received(address,address,uint256,uint256,bytes)
        let fnSelector := 0xf23a6e6100000000000000000000000000000000000000000000000000000000

        if eq(extcodesize(account), 0) { leave } // receiver is eoa

        mstore(0, 0) // zero-out return data location

        mstore(getMemPtr(), fnSelector)
        mstore(safeAdd(getMemPtr(), 0x04), caller())
        mstore(safeAdd(getMemPtr(), 0x24), _from)
        mstore(safeAdd(getMemPtr(), 0x44), id)
        mstore(safeAdd(getMemPtr(), 0x64), amount)
        mstore(safeAdd(getMemPtr(), 0x84), 0x00000000000000000000000000000000000000000000000000000000000000a0)
        mstore(safeAdd(getMemPtr(), 0xa4), 0x0000000000000000000000000000000000000000000000000000000000000000)

        let success := call(gas(), account, 0, getMemPtr(), 0xc4, 0x00, 0x04)
        require(success)

        let response := mload(0)
        require(eq(response, fnSelector))
      }

      function _doSafeBatchTransferAcceptanceCheck(_from, account, _idsOffset, _amountsOffset, _dataOffset, fnCall) {
        // 0xbc197c81 = onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
        let fnSelector := 0xbc197c8100000000000000000000000000000000000000000000000000000000

        if eq(extcodesize(account), 0) { leave } // receiver is eoa

        mstore(0, 0) // zero-out return data location

        let success

        switch fnCall
        case 0 {
          calldatacopy(getMemPtr(), 0x00, calldatasize())

          mstore8(getMemPtr(), 0xbc)
          mstore8(safeAdd(getMemPtr(), 0x01), 0x19)
          mstore8(safeAdd(getMemPtr(), 0x02), 0x7c)
          mstore8(safeAdd(getMemPtr(), 0x03), 0x81)
          mstore(safeAdd(getMemPtr(), 0x04), caller())
          mstore(safeAdd(getMemPtr(), 0x24), _from)

          success := call(gas(), account, 0, getMemPtr(), calldatasize(), 0x00, 0x04)
        }
        case 1 {
          let argsDataLength := sub(calldatasize(), 0x84) 

          mstore(getMemPtr(), fnSelector)
          mstore(safeAdd(getMemPtr(), 0x04), caller())
          mstore(safeAdd(getMemPtr(), 0x24), _from)
          mstore(safeAdd(getMemPtr(), 0x44), add(_idsOffset, 0x20)) // ids offset
          mstore(safeAdd(getMemPtr(), 0x64), add(_amountsOffset, 0x20)) // amounts offset
          mstore(safeAdd(getMemPtr(), 0x84), add(_dataOffset, 0x20)) // data offset

          calldatacopy(safeAdd(getMemPtr(), 0xa4), 0x84, argsDataLength)

          success := call(gas(), account, 0, getMemPtr(), safeAdd(argsDataLength, 0xa4), 0x00, 0x04)
        }
        default {
          revert(0, 0)
        }

        require(success)

        let response := mload(0)
        require(eq(response, fnSelector)) 
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
        revertIfZero(v)
      }

      function decodeAsUint(offset) -> v {
        let pos := add(4, mul(offset, 0x20))
        if lt(calldatasize(), add(pos, 0x20)) {
          revert(0, 0)
        }
        v := calldataload(pos)
      }

      function decodeAsArrayLength(offset) -> l {
        l := calldataload(add(4, offset)) // selector + offset
      }

      /* ---------- calldata encoding functions ---------- */
      function returnUint(v) {
        mstore(0, v)
        return(0, 0x20)
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

      function emitTransferBatch(operator, from, to, idsOffset, amountsOffset) {
        let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                
        let idsLength := decodeAsArrayLength(idsOffset)
        let amountsLength := decodeAsArrayLength(amountsOffset)

        let idsPtr := add(idsOffset, 0x24)
        let amountsPtr := add(amountsOffset, 0x24)

        let argsDataLength := add(0x80, mul(mul(idsLength, 2), 0x20))

        mstore(0x00, idsPtr)
        mstore(0x20, amountsPtr)

        mstore(idsPtr, idsLength)
        mstore(amountsPtr, amountsLength)

        for
          { let i := 0 }
          lt(i, idsLength)
          { i:= add(i, 1) }
        {
          let id := calldataload(add(idsPtr, mul(0x20, i)))
          let amount := calldataload(add(amountsPtr, mul(0x20, i)))

          mstore(add(add(idsPtr, 0x20), mul(i, 0x20)), id)
          mstore(add(add(amountsPtr, 0x20), mul(i, 0x20)), amount)
        }
                
        log4(0x00, argsDataLength, signatureHash, operator, from, to)
      }

      function emitApprovalForAll(owner, operator, approved) {
        let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

        mstore(0x00, approved)

        log3(0x00, 0x20, signatureHash, owner, operator)
      }

      /* -------- storage layout ---------- */
      function balancesPos() -> p { p := 0 }
      function operatorApprovalsPos() -> p { p := 1 }
      function uriLengthPos() -> p { p := 2 }

      /* -------- storage access ---------- */
      function balances(account, id) -> b {
        // key = <balancesPos><address><id>
        // slot = keccak256(key)
        mstore(0x00, balancesPos()) // use scratch space for hashing
        mstore(0x20, account)
        mstore(0x40, id)
        b := keccak256(0x00, 0x60)
      }

      function operatorApprovals(_account, _operator) -> s {
        // key = <operatorApprovalsPos><owner><operator>
        // slot = keccak256(key)
        mstore(0x00, operatorApprovalsPos())
        mstore(0x20, _account)
        mstore(0x40, _operator)
        s := keccak256(0x00, 0x60)
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
      function safeAdd(a, b) -> r {
        r := add(a, b)
        if or(lt(r, a), lt(r, b)) { revert(0, 0) }
      }
      function address0() -> a {
        a := 0x0000000000000000000000000000000000000000000000000000000000000000
      }
      function revertIfZero(addr) {
        require(addr)
      }
      function require(condition) {
        if iszero(condition) { revert(0, 0) }
      }
    }
  }
}