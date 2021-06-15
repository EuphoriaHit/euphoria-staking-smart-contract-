// SPDX-License-Identifier: MIT
pragma solidity 0.9.0;

import "./IERC20.sol";

contract Bakarra {
    address USDT = "0xd9ba894e0097f8cc2bbc9d24d308b98e36dc6d02";

    uint roomCount = 0;

    uint constant CARD_ACE = 1;
    uint constant CARD_TWO = 2;
    uint constant CARD_THREE = 3;
    uint constant CARD_FOUR = 4;
    uint constant CARD_FIVE = 5;
    uint constant CARD_SIX = 6;
    uint constant CARD_SEVEN = 7;
    uint constant CARD_EIGHT = 8;
    uint constant CARD_NINE = 9;
    uint constant CARD_TEN = 10;
    uint constant CARD_QUEEN = 10;
    uint constant CARD_KING = 10;
    uint constant CARD_JACK = 10;

    mapping lots(uint lotId => uint256 lotAmount);
    mapping rooms(uint roomId => Room roomData)

    struct Card {
        uint glasses;
        uint 
    }

    struct Room {
        address payable player;
        address payable dealer;
        uint256 playerLot;
        uint256 dealerLot;
    }

    function startNewGamePlayer(uint256 amount, uint lotId) {
        require(amount == lots[lotId].lotAmount, "Bakkara: Lot amount less");
        IERC20 usdt = IERC20(USDT);
        usdt.transferFrom(msg.sender, address(this), amount);
        room = Room(msg.sender, 0x0, amount, 0);
        roomCount += 1;
        rooms[roomCount] = room;
    }

    function startNewGameDealer(uint256 amount, uint lotId) {
        require(amount == lots[lotId].lotAmount, "Bakkara: Lot amount less");
        IERC20 usdt = IERC20(USDT);
        usdt.transferFrom(msg.sender, address(this), amount);
        room = Room(0x0, msg.sender, 0, amount);
        roomCount += 1;
        rooms[roomCount] = room;
    }

    function connectToGame(uint256 amount, uint lotId, uint roomId) {
        return _connectToGame(amount, lotId, roomId)
    }

    function _connectToGame(uint256 amount, uint lotId, uint roomId) private {
        require(amount == lots[lotId].lotAmount, "Bakkara: Lot amount less");
        IERC20 usdt = IERC20(USDT);
        usdt.transferFrom(msg.sender, address(this), amount);
        Room room = rooms[roomId];

        if(room.player == 0x0) {
            room.player = msg.sender;
            room.playerLot = amount;
        } else {
            room.dealer = msg.sender;
            room.dealerLot = amount;
        }
    }
}
