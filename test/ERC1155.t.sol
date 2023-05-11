// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";
import "forge-std/console2.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {DSInvariantTest} from "./utils/DSInvariantTest.sol";
import {ERC1155TokenReceiver} from "../lib/solmate/src/tokens/ERC1155.sol";

interface ERC1155 {
    function uri(uint256 id) external view returns (string memory);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) public override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract ERC1155Test is DSTestPlus, ERC1155TokenReceiver {
    YulDeployer yulDeployer = new YulDeployer();

    ERC1155 erc1155Contract;

    string uri =
        "dimitarrdimitarrdimitarrdimitarrdimitarrdimitarrdimitarrdimitarrr";

    function setUp() public {
        erc1155Contract = ERC1155(yulDeployer.deployContract("ERC1155", uri));
    }

    function testUri() public {
        uint256 id = 0;
        string memory _test = uri;
        assertEq(erc1155Contract.uri(id), _test);
    }

    function testMintToEOA() public {
        erc1155Contract.mint(address(0xBEEF), 1337, 1, "");

        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1337), 1);
    }

    function testMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        erc1155Contract.mint(address(to), 1337, 1, "");

        assertEq(erc1155Contract.balanceOf(address(to), 1337), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.mintData(), "");
    }

    function testmintBatchToEOA() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;
        amounts[4] = 500;

        erc1155Contract.mintBatch(address(0xBEEF), ids, amounts, "");

        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1337), 100);
        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1338), 200);
        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1339), 300);
        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1340), 400);
        assertEq(erc1155Contract.balanceOf(address(0xBEEF), 1341), 500);
    }

    function testBatchMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;
        amounts[4] = 500;

        erc1155Contract.mintBatch(address(to), ids, amounts, "");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), address(0));
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), amounts);
        assertBytesEq(to.batchData(), "");

        assertEq(erc1155Contract.balanceOf(address(to), 1337), 100);
        assertEq(erc1155Contract.balanceOf(address(to), 1338), 200);
        assertEq(erc1155Contract.balanceOf(address(to), 1339), 300);
        assertEq(erc1155Contract.balanceOf(address(to), 1340), 400);
        assertEq(erc1155Contract.balanceOf(address(to), 1341), 500);
    }

    function testBatchBalanceOf() public {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        erc1155Contract.mint(address(0xBEEF), 1337, 100, "");
        erc1155Contract.mint(address(0xCAFE), 1338, 200, "");
        erc1155Contract.mint(address(0xFACE), 1339, 300, "");
        erc1155Contract.mint(address(0xDEAD), 1340, 400, "");
        erc1155Contract.mint(address(0xFEED), 1341, 500, "");

        uint256[] memory balances = erc1155Contract.balanceOfBatch(tos, ids);

        assertEq(balances[0], 100);
        assertEq(balances[1], 200);
        assertEq(balances[2], 300);
        assertEq(balances[3], 400);
        assertEq(balances[4], 500);
    }

    function testApproveAll() public {
        erc1155Contract.setApprovalForAll(address(0xBEEF), true);

        assertTrue(
            erc1155Contract.isApprovedForAll(address(this), address(0xBEEF))
        );
    }
}
