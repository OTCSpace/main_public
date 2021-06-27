// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EscrowTrade is Ownable {

    enum Status{PENDING, BROKEN, SUCCESS}

    using SafeMath for uint256;

    event contractCreated(uint256 contractID, address buyer, address seller);
    event confirmedByBuyer(uint256 contractID);
    event confirmedBySeller(uint256 contractID);
    event contractBroken(uint256 contractID);
    event contractSuccess(uint256 contractID);

    struct Contract{
        address buyer;
        address seller;
        address buyerToken; // if buyerToken address equals 0x0, it means BNB
        address sellerToken;
        uint256 buyAmount;
        uint256 sellAmount;
        uint256 collateral;
        uint256 lockTime;
        bool buyerConfirmed;
        bool sellerConfirmed;
        Status state;
    }

    mapping(uint256 => Contract) list;
    mapping(uint256 => bool) isExist;

    uint256 public lockDuration = 1 days;

    constructor() public {}

    function createContract(
        uint256 contractId,
        address _buyer,
        address _seller,
        address _buyToken,
        address _sellToken,
        uint256 _buyAmount,
        uint256 _sellAmount) external onlyOwner {
        require(isExist[contractId] == false, "CreateContract: already exist");
        Contract memory newContract = Contract({
            buyer: _buyer,
            seller: _seller,
            buyerToken: _buyToken,
            sellerToken: _sellToken,
            buyAmount: _buyAmount,
            sellAmount: _sellAmount,
            collateral: _buyAmount.div(2),
            lockTime: lockDuration.add(block.timestamp),
            buyerConfirmed: false,
            sellerConfirmed: false,
            state: Status.PENDING
        });
        list[contractId] = newContract;
        isExist[contractId] = true;

        emit contractCreated(contractId, _buyer, _seller);
    }

    function confirmByBuyer(uint256 contractID) external payable {
        require(isExist[contractID] == true, "ConfirmByBuyer: not exist");
        require(msg.sender == list[contractID].buyer, "ConfirmByBuyer: not buyer");
        require(list[contractID].buyerConfirmed == false, "ConfirmByBuyer: already confirmed");
        require(list[contractID].state == Status.PENDING, "ConfirmByBuyer: finished");

        address buyerToken = list[contractID].buyerToken;
        uint256 buyAmount = list[contractID].buyAmount;

        if(buyerToken == address(0x0)){
            require(msg.value >= buyAmount, "ConfirmByBuyer: insufficient funds");
        }else{
            IERC20(buyerToken).transferFrom(msg.sender, address(this), buyAmount);
        }
        list[contractID].buyerConfirmed = true;

        emit confirmedByBuyer(contractID);
    }

    function confirmBySeller(uint256 contractID) external payable {
        require(isExist[contractID] == true, "ConfirmBySeller: not exist");
        require(msg.sender == list[contractID].seller, "ConfirmBySeller: not seller");
        require(list[contractID].sellerConfirmed == false, "ConfirmBySeller: already confirmed");
        require(list[contractID].state == Status.PENDING, "ConfirmBySeller: finished");

        address buyerToken = list[contractID].buyerToken;
        uint256 collateral = list[contractID].collateral;

        if(buyerToken == address(0x0)){
            require(msg.value >= collateral, "ConfirmByBuyer: insufficient funds");
        }else{
            IERC20(buyerToken).transferFrom(msg.sender, address(this), collateral);
        }
        list[contractID].sellerConfirmed = true;

        emit confirmedBySeller(contractID);
    }

    function breakContract(uint256 contractID) external {
        require(isExist[contractID] == true, "breakContract: not exist");
        require(msg.sender == list[contractID].seller, "breakContract: not seller");
        require(list[contractID].state == Status.PENDING, "breakContract: finished");
        require(list[contractID].sellerConfirmed == true, "breakContract: not confirmed by seller");
        require(list[contractID].lockTime <= block.timestamp, "breakContract: not unlocked");

        address buyerToken = list[contractID].buyerToken;
        uint256 buyAmount = list[contractID].buyAmount;
        uint256 collateral = list[contractID].collateral;

        address buyer = list[contractID].buyer;

        if(buyerToken == address(0x0)){
            payable(buyer).transfer(buyAmount.add(collateral));

        }else{
            IERC20(buyerToken).transfer(buyer, buyAmount.add(collateral));
        }

        list[contractID].state = Status.BROKEN;

        emit contractBroken(contractID);
    }

    function successContract(uint256 contractID) external {
        require(isExist[contractID] == true, "breakContract: not exist");
        require(msg.sender == list[contractID].seller, "breakContract: not seller");
        require(list[contractID].state == Status.PENDING, "breakContract: finished");
        require(list[contractID].sellerConfirmed == true, "breakContract: not confirmed by seller");
        require(list[contractID].lockTime <= block.timestamp, "breakContract: not unlocked");

        address buyer = list[contractID].buyer;
        address sellerToken = list[contractID].sellerToken;
        uint256 sellAmount = list[contractID].sellAmount;

        IERC20(sellerToken).transferFrom(msg.sender, buyer, sellAmount);

        address buyerToken = list[contractID].buyerToken;
        uint256 buyAmount = list[contractID].buyAmount;
        uint256 collateral = list[contractID].collateral;

        if(buyerToken == address(0x0)){
            payable(msg.sender).transfer(buyAmount.add(collateral));

        }else{
            IERC20(buyerToken).transfer(msg.sender, buyAmount.add(collateral));
        }

        list[contractID].state = Status.SUCCESS;

        emit contractSuccess(contractID);
    }
}
