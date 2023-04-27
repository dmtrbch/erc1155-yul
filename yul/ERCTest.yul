object "ERCTest" {
  code {
    sstore(0, codesize())
   
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }
  object "runtime" {
    code {
      switch getSelector()
      case 0x7eed0172 /* myFunc() */ {
        mstore(0, 6)
        return(0, 0x20)
      }
      case 0x8da5cb5b /* owner() */ {
        returnUint(owner())
      }
      default {
        revert(0, 0)
      }

      function getSelector() -> selector {
        selector := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function returnUint(v) {
        mstore(0, v)
        return(0, 0x20)
      }

      function owner() -> o {
        o := sload(0)
      }
    }
  }
}