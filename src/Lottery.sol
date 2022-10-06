// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract Lottery {
    uint256 received_msg_value;  // 지금까지 모인 msg.value의 총 합
    uint256 time;
    address[] player;  // 로또를 산 구매자
    address[] winner;
    uint16 jackpot;
    bool nodraw;

    mapping(address => uint16) public player_num;    // 각 구매자들이 구매한 로또 번호
    mapping(address => uint256) public balances;      // 각 구매자들의 잔고


    constructor () {
        received_msg_value = 0;
        time = block.timestamp;
        jackpot = 13;
        nodraw = false;
    }


// 로또 번호 뽑기(1개만 가능)
    function buy(uint16 number) public payable { 
        require(msg.value == 0.1 ether); // testInsufficientFunds를 통과하기 위한 조건
        if (nodraw) {
            require(time + 24 hours >= block.timestamp);
            nodraw = false;
        }
        else {
            require(time + 24 hours > block.timestamp);
        }
        require(player_num[msg.sender] != number + 1);  // 26-27: testnoduplicate
        player_num[msg.sender] = number + 1;

        player.push(msg.sender);

        received_msg_value += msg.value; 

    }


// 로또 당첨 번호 뽑기
// 당첨된 사람들에게 당첨금 주기
    function draw() public { 
        require(block.timestamp >= time + 24 hours);
        require(!nodraw);

        // player에서 buy한 번호가 winningNumber과 같은 player를 찾아서 winner에 넣어주기
        for (uint i = 0; i < player.length; i++) {
            address addr = player[i];
            if (player_num[addr] - 1 == winningNumber()) {
                winner.push(addr);
            }
        }

        // winner에게 received_msg_value 전달하기
        // 당첨자의 수에 따라 상금 나눠주기
        // 1. winner의 수
        // 2. 당첨금을 winner 수에 따라 나누기
        // 3. 당첨된 사람들에게 나눠주기

        if (winner.length > 0) {   
        // if 조건 없으면 "Division or modulo by 0" error 발생
            uint prize = received_msg_value / winner.length;
            //received_msg_value = 0;

            for (uint i = 0; i < winner.length; i++) {
                address addr = winner[i];
                balances[addr] += prize;
            }
        }
    }


// 당첨자가 없으면 다음 회차로 당첨금 넘기기
// 당첨금 전달
    function claim() public { 
        require(block.timestamp >= time + 24 hours);
        nodraw = true;

        uint amount = balances[msg.sender];
        //console.log(amount);

        balances[msg.sender] = 0;
        payable(msg.sender).call{value:amount}("");
    }


    function winningNumber() public view returns (uint16) {
        return jackpot;
        // view 안하면 warning 뜸
        // pure로 값을 전달하려면 변수를 쓰지 말고 
        // 바로 return 값으로 winningNumber를 넘겨주면 됨 / ex) return 13;
    }
}

/*

[요구사항]
1. testNoBuyAfterPhaseEnd / testNoDrawDuringSellPhase / testNoClaimDuringSellPhase / testDraw
   => 1) 24시간 동안은 buy만 할 수 있어야 함
      2) 24시간 후에는 draw, claim만 할 수 있어야 함
      3) claim이 끝난 후에 다시 buy 할 수 있어야 함
2. 

*/