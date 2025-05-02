// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IFonzoMarket} from "../src/interfaces/IFonzoMarket.sol";
import {FonzoMarket} from "../src/FonzoMarket.sol";
import {MockFtsoV2} from "./MockFtsoV2.sol";

contract FonzoMarketTest is Test {
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    address private userC = makeAddr("userC");
    address private userD = makeAddr("userD");
    address private owner = makeAddr("owner");

    bytes21 private constant BTC_USD_ID = 0x014254432f55534400000000000000000000000000; // BTC/USD
    bytes21 private constant FLR_USD_ID = 0x01464c522f55534400000000000000000000000000; // FLR/USD

    MockFtsoV2 private ftsoV2;
    FonzoMarket private fonzo;

    uint256 private constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        vm.deal(userA, INITIAL_BALANCE);
        vm.deal(userB, INITIAL_BALANCE);
        vm.deal(userC, INITIAL_BALANCE);
        vm.deal(owner, INITIAL_BALANCE);

        ftsoV2 = new MockFtsoV2();
        fonzo = new FonzoMarket(owner, address(ftsoV2));

        vm.warp(25 minutes);

        updateFlarePriceFeed(1);
        fonzo.initializeMarket(FLR_USD_ID);
    }

    function test_constructor() public view {
        assertEq(fonzo.owner(), owner);
        assertEq(address(fonzo.ftsoV2()), address(ftsoV2));
    }

    function updateFlarePriceFeed(uint256 value) internal {
        ftsoV2.updateFeed(FLR_USD_ID, value * 10 ** 8, 8, uint64(block.timestamp));
    }

    function test_initializeMarket_succeeds() public {
        ftsoV2.updateFeed(BTC_USD_ID, 96e8, 8, uint64(block.timestamp));

        vm.expectEmit();
        emit IFonzoMarket.InitializedMarket(BTC_USD_ID, owner);
        vm.prank(owner);
        fonzo.initializeMarket(BTC_USD_ID);
    }

    function test_initializeMarket_reverts_when_market_already_exist() public {
        ftsoV2.updateFeed(BTC_USD_ID, 96e8, 8, uint64(block.timestamp));

        fonzo.initializeMarket(BTC_USD_ID);

        vm.expectRevert(IFonzoMarket.MarketAlreadyExist.selector);
        fonzo.initializeMarket(BTC_USD_ID);
    }

    function test_bearish_succeeds() public {
        bytes32 positionId = keccak256(abi.encodePacked(FLR_USD_ID, uint256(2), userA));

        vm.prank(userA);
        vm.expectEmit();
        emit IFonzoMarket.Predicted(FLR_USD_ID, 2, userA, positionId, IFonzoMarket.Option.DOWN, 2 ether);
        fonzo.bearish{value: 2 ether}(FLR_USD_ID, 2);
    }

    function test_bearish_reverts_when_market_does_not_exist() public {
        vm.expectRevert(IFonzoMarket.MarketNotInitialized.selector);
        vm.prank(userA);
        fonzo.bearish{value: 2 ether}(BTC_USD_ID, 1);
    }

    function test_bearish_reverts_when_entry_not_allowed() public {
        vm.warp(block.timestamp + 5 minutes + 20);
        vm.expectRevert(IFonzoMarket.EntryClosed.selector);
        vm.prank(userA);
        fonzo.bearish{value: 2 ether}(FLR_USD_ID, 1);
    }

    function test_bearish_reverts_if_no_stake() public {
        vm.prank(userA);
        vm.expectRevert(IFonzoMarket.AmountCannotBeZero.selector);
        fonzo.bearish(FLR_USD_ID, 2);
    }

    function test_bearish_reverts_when_position_exist() public {
        vm.prank(userA);
        fonzo.bearish{value: 2 ether}(FLR_USD_ID, 2);

        vm.prank(userA);
        vm.expectRevert(IFonzoMarket.PositionExist.selector);
        fonzo.bearish{value: 3 ether}(FLR_USD_ID, 2);
    }
}
