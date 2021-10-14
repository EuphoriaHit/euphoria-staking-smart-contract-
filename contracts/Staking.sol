// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Ownable.sol";
import "./ABDKMathQuad.sol";

interface ERC20 {
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool); 
}


contract Staking is Ownable {
    using ABDKMathQuad for *;

    ERC20 private ERC20Interface;

    constructor(uint256 _supply, address _owner) {
        poolBalance = ABDKMathQuad.fromUInt(_supply);
        ERC20Interface = ERC20(_owner);
        initialPoolBalance = _supply;
        dailyReward = dailyReward = ABDKMathQuad.div(ABDKMathQuad.fromUInt(initialPoolBalance), ABDKMathQuad.fromUInt(1460));
    }

    struct Stakeholder {
        address holderAddress;
        bytes16 balance;
    }

    bytes16 private dailyReward; // Daily rewards amount in NanoTokens value
    bytes16 private poolBalance; // Amount of left NanoTokens value that is being spread within 4 years.
    uint256 private initialPoolBalance; // Amount of initial NanoTokens value
    mapping(address => Stakeholder) stakeHolders;
    address[] internal stakeHoldersList;

    // <================================ INTERNAL FUNCTIONS ================================>

    function calculateReward(bytes16 stakeHolderBalance, bytes16 sumOfBalances, bytes16 localDailyReward)
    internal
    pure
    returns(bytes16)
    {
        bytes16 oneHunderd = ABDKMathQuad.fromUInt(100);
        if(stakeHolderBalance == bytes16(0)) return 0;
        bytes16 stakePercentage = ABDKMathQuad.mul(ABDKMathQuad.div(stakeHolderBalance, sumOfBalances), oneHunderd);

        return ABDKMathQuad.div(ABDKMathQuad.mul(localDailyReward, stakePercentage) , oneHunderd);
    }

    function totalStakeHoldersBalance()
       internal
       view
       returns(bytes16)
   {
       bytes16 _totalRewards;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           _totalRewards = ABDKMathQuad.add(_totalRewards, stakeHolders[stakeHoldersList[s]].balance);
       }
       return _totalRewards;
   }

    // <================================ PUBLIC FUNCTIONS ================================>

    function decimals() public pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) public pure returns(uint256) {
        return token * (10 ** decimals());
    }

    function stakeHolderBalanceOf(address _stakeholder)
        public
        view
        returns(uint256)
    {
        return ABDKMathQuad.toUInt(stakeHolders[_stakeholder].balance);
    }

    function transferTokensToContract() public onlyOwner
    {
        ERC20Interface.transferFrom(msg.sender, address(this), initialPoolBalance);
    }

   function isStakeHolder(address _address) public view returns(bool, uint256) {
       address[] memory localStakeHoldersList = stakeHoldersList;
       for(uint256 sHolderId = 0; sHolderId < stakeHoldersList.length; sHolderId++) {
           if(_address == localStakeHoldersList[sHolderId]) return (true, sHolderId);
       }
       return (false, 0);
   }

   function addStakeHolder(address _stakeholder) public {
       require(_stakeholder != address(0), "No zero address is allowed");
       (bool _isStakeHolder, ) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == false, "Stake holder with provided address already exists");
       if(!_isStakeHolder) {
           stakeHolders[_stakeholder].holderAddress = _stakeholder;
           stakeHoldersList.push(_stakeholder);
       }
   }

   function removeStakeHolder(address _stakeholder) public {
       require(_stakeholder != address(0), "No zero address is allowed");
       (bool _isStakeHolder, uint256 sHolderId) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == true, "There is not any stake holder with provided address");

       if(_isStakeHolder) {
           delete stakeHolders[_stakeholder];
           stakeHoldersList[sHolderId] = stakeHoldersList[stakeHoldersList.length - 1];
           stakeHoldersList.pop();
       }
   }

   function createStake(uint256 _stake)
       public
   {
        require(msg.sender != address(0), "No zero address is allowed");
        require(_stake >= toNanoToken(10000), "Minimal stake value is 10 000 euphoria tokens");
        require(ABDKMathQuad.toUInt(poolBalance) > 0, "Pool is empty. System does not accept any new stakes");
        if(stakeHolders[msg.sender].balance == 0) addStakeHolder(msg.sender);
        ERC20Interface.transferFrom(msg.sender, address(this), _stake);
        stakeHolders[msg.sender].balance = ABDKMathQuad.add(stakeHolders[msg.sender].balance, ABDKMathQuad.fromUInt(_stake));
   }

    function balanceOfContract()
       public
       view
       returns(uint256)
   {
       return ERC20Interface.balanceOf(address(this));
   }

    function getPoolBalance() public view returns(uint256) {
        return ABDKMathQuad.toUInt(poolBalance);
    }

    function distributeRewards()
        public
        onlyOwner
    {
        require(stakeHoldersList.length != 0, "There are currently no stake holders. Cannot distribute rewards");
        require(ABDKMathQuad.toUInt(poolBalance) > 0, "Pool is empty. Cannot distribute rewards");

        bytes16 sumOfBalances = totalStakeHoldersBalance();
        bytes16 localDailyReward = dailyReward;

        for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            address _stakeHolder = stakeHoldersList[s];
            bytes16 localStakeHolderBalance = stakeHolders[_stakeHolder].balance;
            bytes16 reward = calculateReward(localStakeHolderBalance, sumOfBalances, localDailyReward);
            
            //This part checks if the total poolBalance is lower than reward value and then it adds the remaining amount to the last user Address in stakeHoldersList array
            //This is done in order to completely empty the local poolBalance variable
            if(s == stakeHoldersList.length-1) {
                stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(reward, localStakeHolderBalance);
                uint256 totalBalance = ABDKMathQuad.toUInt(sumOfBalances);
                if(totalBalance < initialPoolBalance && (initialPoolBalance-totalBalance) < ABDKMathQuad.toUInt(reward)) {
                    uint256 remainder = initialPoolBalance - totalBalance;
                    stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(ABDKMathQuad.fromUInt(remainder), localStakeHolderBalance);
                    poolBalance = 0;
                }
                break;
            }
            
            stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(reward, localStakeHolderBalance);
        }
        
        poolBalance = ABDKMathQuad.sub(poolBalance, dailyReward); //Subtract dailyReward from local poolBalance variable
    }

    function unStake()
        public
    {
        require(stakeHolders[msg.sender].holderAddress != address(0), "This user must be a stake holder");
        uint256 reward = ABDKMathQuad.toUInt(stakeHolders[msg.sender].balance);
        require(reward > 0, "User does not have any tokens in his balance");
        // Check if the pool is Empty and the last left user is trying to withdraw its balance. This check is done in order to completely empty the payable poolBalance of contract
        if(stakeHoldersList.length == 1) {
            if(getPoolBalance() == 0){ 
                ERC20Interface.transfer(msg.sender, balanceOfContract());
                removeStakeHolder(msg.sender);
                return;
            }
        }

        ERC20Interface.transfer(msg.sender, reward);
        removeStakeHolder(msg.sender);
    }
}