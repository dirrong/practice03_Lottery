// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    uint256 received_msg_value;
    function setUp() public {
       lottery = new Lottery();
       received_msg_value = 0;
       vm.deal(address(this), 100 ether);
       vm.deal(address(1), 100 ether);
       vm.deal(address(2), 100 ether);
       vm.deal(address(3), 100 ether);
    }

    function testGoodBuy() public {
        lottery.buy{value: 0.1 ether}(0);
    }

    function testInsufficientFunds1() public {
        vm.expectRevert();
        lottery.buy(0);
    }

    function testInsufficientFunds2() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether - 1}(0);
    }

    function testInsufficientFunds3() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether + 1}(0);
    }

    function testNoDuplicate() public { // 한 사람이 중복으로 buy 불가능
        lottery.buy{value: 0.1 ether}(0);
        vm.expectRevert();
        lottery.buy{value: 0.1 ether}(0);
    }

    function testSellPhaseFullLength() public { // 24시간이 지나기 전에는 로또 살 수 있음
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    function testNoBuyAfterPhaseEnd() public { // 장이 끝나면 더이상 살 수 없음
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        vm.expectRevert();
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    function testNoDrawDuringSellPhase() public { // 장이 열리는 동안에는 draw 불가능
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.draw();
    }

    function testNoClaimDuringSellPhase() public { // 장이 열리는 동안에는 claim 불가능
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.claim();
    }

    function testDraw() public { // buy하고 24시간 후에 draw 가능
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
    }

    function getNextWinningNumber() private returns (uint16) { 
        // snapshot: 블록체인 상태 확인 후 생성된 식별자 반환
        // revertTo: 블록체인의 상태를 주어진 상태로 되돌림
        uint256 snapshotId = vm.snapshot();
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        uint16 winningNumber = lottery.winningNumber();
        vm.revertTo(snapshotId);
        return winningNumber;
    }

    function testClaimOnWin() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        uint256 expectedPayout = address(lottery).balance;
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, expectedPayout);
    }

    function testNoClaimOnLose() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0);
    }

    function testNoDrawDuringClaimPhase() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        vm.expectRevert();
        lottery.draw();
    }

    function testRollover() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();

        winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0.2 ether);
    }

    function testSplit() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.deal(address(1), 0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();

        lottery.claim();
        assertEq(received_msg_value, 0.1 ether);

        vm.prank(address(1));
        lottery.claim();
        assertEq(address(1).balance, 0.1 ether);
    }

    receive() external payable {
        received_msg_value = msg.value;
    }
}