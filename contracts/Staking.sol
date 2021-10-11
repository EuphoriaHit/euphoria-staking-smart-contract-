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

    ERC20 public ERC20Interface = ERC20(0x741017087F547ac32ece5431d2C2E418d126e80D);

    constructor(uint256 _supply) {
        poolBalance = ABDKMathQuad.fromUInt(_supply);
        initialPoolBalance = _supply;
    }

    struct Stakeholder {
        address holderAddress;
        bytes16 balance;
        uint256 stake;
    }

    //bool isConfigured;
    //mapping (address => bytes16) stakeHolderDailyRewards;
    bytes16 private poolBalance; // Amount of left NanoTokens value that is being spread within 4 years
    uint256 private initialPoolBalance; // Amount of initial NanoTokens value
    mapping(address => Stakeholder) stakeHolders;
    address[] internal stakeHoldersList;
    //bytes16 private dailyReward; // // Amount of fixed value that will be subtracted everyday within 4 years 

    // <================================ INTERNAL FUNCTIONS ================================>

    function decimals() public pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) public pure returns(uint256) {
        return token * (10 ** decimals());
    }


    function calculateReward(address _stakeHolder, bytes16 sumOfBalances, bytes16 dailyReward)
    internal
    view
    returns(bytes16)
    {
        
        bytes16 stakeHolderBalance = stakeHolders[_stakeHolder].balance;
        if(stakeHolderBalance == bytes16(0)) return ABDKMathQuad.fromInt(0);
        bytes16 stakePercentage = ABDKMathQuad.mul(ABDKMathQuad.div(stakeHolderBalance, sumOfBalances), ABDKMathQuad.fromUInt(100));

        return ABDKMathQuad.div(ABDKMathQuad.mul(dailyReward, stakePercentage) , ABDKMathQuad.fromUInt(100));
    }

/*
    function calculateRewards()
    internal
    {
        bytes16 stakeHoldersTotalBalance = totalStakeHolderBalanceBytes();

        for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            address _stakeHolder = stakeHoldersList[s];
            bytes16 stakeHolderBalance = stakeHolders[_stakeHolder].balance;
            //if(stakeHolderStake == 0) return ABDKMathQuad.fromInt(0);
            bytes16 stakePercentage = ABDKMathQuad.mul(ABDKMathQuad.div(stakeHolderBalance, stakeHoldersTotalBalance), ABDKMathQuad.fromUInt(100));
            stakeHolderDailyRewards[_stakeHolder] = ABDKMathQuad.div(ABDKMathQuad.mul(dailyReward, stakePercentage) , ABDKMathQuad.fromUInt(100));
        }
    }
*/

    function stakeHolderBalanceOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return ABDKMathQuad.toUInt(stakeHolders[_stakeholder].balance);
   }

    function totalStakeHolderBalancesBytes()
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

   function totalStakeHolderBalances()
       public
       view
       returns(uint256)
   {
       bytes16 _totalRewards;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           _totalRewards = ABDKMathQuad.add(_totalRewards, stakeHolders[stakeHoldersList[s]].balance);
       }
       return ABDKMathQuad.toUInt(_totalRewards);
   }

    // <================================ PUBLIC FUNCTIONS ================================>

    function transferTokensToContract() public onlyOwner
    {
        //require(initialPoolBalance != 0, "Staking contract has already been configured");
        ERC20Interface.transferFrom(msg.sender, address(this), initialPoolBalance);
    }

   function isStakeHolder(address _address) public view returns(bool, uint256) {
       for(uint256 sHolderId = 0; sHolderId < stakeHoldersList.length; sHolderId++) {
           if(_address == stakeHoldersList[sHolderId]) return (true, sHolderId);
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
        if(stakeHolders[msg.sender].balance == ABDKMathQuad.fromUInt(0)) addStakeHolder(msg.sender);
        ERC20Interface.transferFrom(msg.sender, address(this), _stake);
        stakeHolders[msg.sender].stake += _stake;
        //poolBalance = ABDKMathQuad.add(poolBalance, ABDKMathQuad.fromUInt(_stake));
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

    function getTotalStakes() public view returns(uint256) {
        uint256 _totalStakes;
        for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            _totalStakes += stakeHolders[stakeHoldersList[s]].stake;
        }
        return _totalStakes;
    }

    function getStakeOf(address _stakeHolder) public view returns(uint256) {
        return stakeHolders[_stakeHolder].stake;
    }

    function getDailyReward() public view returns(uint256) {
        return initialPoolBalance / 10;
    }

    function distributeRewards()
        public
        onlyOwner
    {
        require(stakeHoldersList.length != 0, "There are currently no stake holders. Cannot distribute rewards");
        require(ABDKMathQuad.toUInt(poolBalance) > 0, "Pool is empty. Cannot distribute rewards");

        bytes16 sumOfBalances = totalStakeHolderBalancesBytes();
        bytes16 dailyReward = ABDKMathQuad.div(ABDKMathQuad.fromUInt(initialPoolBalance), ABDKMathQuad.fromUInt(10));

        for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            address _stakeHolder = stakeHoldersList[s];
            bytes16 reward = calculateReward(_stakeHolder, sumOfBalances, dailyReward);

            poolBalance = ABDKMathQuad.sub(poolBalance, reward);
            
            if(s == stakeHoldersList.length - 1) {
                stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(reward, stakeHolders[_stakeHolder].balance);
                uint256 totalBalance = totalStakeHolderBalances();
                if(totalBalance < initialPoolBalance && (initialPoolBalance-totalBalance) < ABDKMathQuad.toUInt(reward)) {
                    uint256 remainder = initialPoolBalance - totalBalance;
                    stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(ABDKMathQuad.fromUInt(remainder), stakeHolders[_stakeHolder].balance);
                    poolBalance = ABDKMathQuad.fromUInt(0);
                }
                break;
            }
            
            stakeHolders[_stakeHolder].balance = ABDKMathQuad.add(reward, stakeHolders[_stakeHolder].balance);
        }

    }

    function unStake()
        public
    {
        require(stakeHolders[msg.sender].holderAddress != address(0), "This user must be a stake holder");
        uint256 reward = ABDKMathQuad.toUInt(stakeHolders[msg.sender].balance);
        require(reward > 0, "User does not have any tokens in his balance");
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