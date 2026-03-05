// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AdvancedVault {

    struct Vault {
        uint balance;
        uint unlockTime;
    }

    mapping(address => Vault) public vaults;

    address public immutable owner;
    bool public paused;
    uint public constant MIN_LOCK = 1 days;
    bool private locked;

    event Deposit(address indexed caller, uint amount, uint unlockTime);
    event NormalWithdraw(address indexed caller, uint amount);
    event PenaltyWithdraw(address indexed caller, uint amount, uint finalAmount, uint penalty);
    event EmeregencyWithdraw(address indexed caller, uint amount);
    event Pause();
    event UnPause();

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(paused == false, "contract is paused");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "reentrant");
        locked = true;
        _;
        locked = false;
    }
    constructor() {
        owner = msg.sender;
    }


    function pause() public onlyOwner{
        paused = true;

        emit Pause();
    }

    function unPause() public onlyOwner {
        paused = false;

        emit UnPause();
    }

    function getVault(address user) public view returns(uint balance ,uint unlockTime) {
        Vault storage u = vaults[user];
        return(u.balance, u.unlockTime);
    }

    function getContractBalance() public view returns(uint) {
        return address(this).balance;
    }

    function deposit(uint lockDuration) payable public whenNotPaused {
        require(msg.value > 0, "msg.value is empty");
        require(lockDuration >= MIN_LOCK, "Lock duration too short");

        Vault storage u = vaults[msg.sender];

        u.balance += msg.value;
        uint newUnlock = block.timestamp + lockDuration;

        if(newUnlock > u.unlockTime){
            u.unlockTime = newUnlock;
        }

        emit Deposit(msg.sender, msg.value, u.unlockTime);
    }

    function withdraw(uint amount) public whenNotPaused nonReentrant {
            Vault storage u = vaults[msg.sender];
            require(amount > 0, "Zero amount");
            require(u.balance >= amount, "You don't have any ETH to withdraw");

        if(block.timestamp >= u.unlockTime){
            u.balance -= amount;
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "trasnfer failed");

            emit NormalWithdraw(msg.sender, amount);
        }else{
            uint penalty = (amount * 10) / 100;
            uint finalAmount = amount - penalty;

            u.balance -= amount;

            (bool s1, ) = payable(msg.sender).call{value: finalAmount}("");
            require(s1, "trasnfer failed");

            (bool s2, ) = payable(owner).call{value: penalty}("");
            require(s2, "trasnfer failed");  

            emit PenaltyWithdraw(msg.sender, amount, finalAmount, penalty); 
        }

    }
    
    function emergencyWithdraw() public onlyOwner nonReentrant {
        
        uint amount = address(this).balance;
        
        paused = true;
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "trasnfer failed");

        emit EmeregencyWithdraw(owner, amount);
    }

    function getBalance() public view returns(uint) {
        return vaults[msg.sender].balance;
    }

    function getUnlockTime() public view returns(uint) {
        return vaults[msg.sender].unlockTime;
    }

    receive() external payable {
        revert("use deposit()");
    }


}
