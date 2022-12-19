// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./IRoomShare.sol";
contract RoomShare is IRoomShare {
  uint public rentId = 0;
  uint public roomId = 0;

  mapping(uint => Room) public roomId2room;
  mapping(uint => Rent[]) public roomId2rent;
  mapping(address => Rent[]) public renter2rent;

  function getMyRents() override external view returns(Rent[] memory) {
    /* 함수를 호출한 유저의 대여 목록을 가져온다. */
    return renter2rent[msg.sender];
  }

  function getRoomRentHistory(uint _roomId) override external view returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    return roomId2rent[_roomId];
  }
  function shareRoom( string calldata name,
                      string calldata location,
                      uint price ) override external {
    /**
     * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
     * 2. 방의 id와 방 객체를 매핑한다.
     */
    uint newid = roomId++;
    bool[] memory isRented = new bool[](365);
    roomId2room[newid] = Room(newid, name, location, true, price, msg.sender, isRented);
    emit NewRoom(newid);
  }

  function rentRoom(uint _roomId, uint checkInDate, uint checkOutDate) override payable external {
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei)
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
     */

    Room storage room = roomId2room[_roomId];
    require(room.isActive, "Room is inactive");
    for (uint d = checkInDate; d < checkOutDate; d++) {
      require(!room.isRented[d], "Room is in use");
    }

    uint finneys = (checkOutDate - checkInDate) * room.price;
    uint amount = finneys*1e15;
    require(msg.value >= amount, "Not enough ether");
    _sendFunds(room.owner, amount);

    _createRent(room.id, checkInDate, checkOutDate);
  }

  function _createRent(uint256 _roomId, uint256 checkInDate, uint256 checkOutDate) internal {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */
    Room storage room = roomId2room[_roomId];
    for (uint d = checkInDate; d < checkOutDate; d++) {
      room.isRented[d] = true;
    }

    uint newid = rentId++;
    roomId2rent[_roomId].push(Rent(newid, _roomId, checkInDate, checkOutDate, msg.sender));
    renter2rent[msg.sender].push(Rent(newid, _roomId, checkInDate, checkOutDate, msg.sender));
    emit NewRent(_roomId, newid);

  }

  function _sendFunds (address owner, uint256 value) internal {
    payable(owner).transfer(value);
    emit Transfer(msg.sender, owner, value);
  }



  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) override external view returns(uint[2] memory) {
    /**
     * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우,
     * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
     * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
     */
    uint[2] memory minDate = [uint(1000),uint(1000)];
    Rent[] storage rents = roomId2rent[_roomId];
    for (uint i = 0; i < rents.length; i++) {
      uint d1 = rents[i].checkInDate;
      uint d2 = rents[i].checkOutDate;

      if (d1 < checkOutDate && checkInDate < d2) {
        if (d2 == minDate[0]) { //연속 구간 합치기
          minDate[0] = d1;
        }
        else if(minDate[1] == d1) { //연속 구간 합치기
          minDate[1] = d2;
        }
        else if(d1 < minDate[0]) { //연속 아닐 시 최소 구간으로
          minDate[0] = d1;
          minDate[1] = d2;
        }
      }
    }
    require(minDate[0] != 1000, "Invalid recommendDate params");
    return minDate;
  }



  function markRoomAsInactive(uint256 _roomId) override external {
    Room storage room = roomId2room[_roomId];
    require(room.owner == msg.sender, "Room not owned by user");
    room.isActive = false;
  }
  function initializeRoomShare(uint _roomId, uint day) override external {
    /* Not Implemented */
  }
}
