// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Ownable.sol";
import "./IERC20.sol";
import "./ABDKMathQuad.sol";
import "./ABDKMath64x64.sol";

contract Staking is Ownable {
    using ABDKMathQuad for *;

    constructor(uint256 _supply) {
        poolBalance = ABDKMathQuad.fromUInt(toNanoToken(_supply));
        initialPoolBalance = toNanoToken(_supply);
        dailyReward = ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromUInt(_supply), ABDKMathQuad.fromUInt(365*4)), ABDKMathQuad.fromUInt(10 ** decimals()));
    }

    struct Stakeholder {
        address holderAddress;
        bytes16 rewardBalance;
        uint256 stake;
    }

    address[] internal stakeHoldersList;
    mapping(address => Stakeholder) stakeHolders;

    uint256 private initialPoolBalance; // Amount of initial NanoTokens value
    bytes16 private poolBalance; // Amount of left NanoTokens value that is being spread within 4 years
    bytes16 private dailyReward; // // Amount of fixed value that will be subtracted everyday within 4 years 

    // <================================ INTERNAL FUNCTIONS ================================>

    function decimals() internal pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) internal pure returns(uint256) {
        return token * (10 ** decimals());
    }

   function isStakeHolder(address _address) public view returns(bool, uint256) {
       for(uint256 sHolderId = 0; sHolderId < stakeHoldersList.length; sHolderId++) {
           if(_address == stakeHoldersList[sHolderId]) return (true, sHolderId);
       }
       return (false, 0);
   }

   function addStakeHolder(address _stakeholder) public {
       (bool _isStakeHolder, ) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == false, "Stake holder with provided address already exists");
       if(!_isStakeHolder) {
           stakeHolders[_stakeholder].holderAddress = _stakeholder;
           stakeHoldersList.push(_stakeholder);
       }
   }

   function removeStakeHolder(address _stakeholder) public {
       (bool _isStakeHolder, uint256 sHolderId) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == true, "There is not any stake holder with provided address");

       if(_isStakeHolder) {
           delete stakeHolders[_stakeholder];
           stakeHoldersList[sHolderId] = stakeHoldersList[stakeHoldersList.length - 1];
           stakeHoldersList.pop();
       }
   }

   function stakeOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return stakeHolders[_stakeholder].stake; //stakes[_stakeholder];
   }

    // <================================ PUBLIC FUNCTIONS ================================>

    function balanceOfPool()
       public
       view
       returns(int256)
   {
       return ABDKMathQuad.toInt(poolBalance);
   }

   function totalStakes()
       public
       view
       returns(uint256)
   {
       uint256 _totalStakes = 0;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            _totalStakes += stakeHolders[stakeHoldersList[s]].stake;
       }
       
       return _totalStakes;
   }

    function createStakeMod(address _address, uint256 _stake)
       public
   {
        if(stakeHolders[_address].stake == 0) addStakeHolder(_address);
        stakeHolders[_address].stake += _stake * (10 ** decimals());
   }

   function createStake(uint256 _stake)
       public
   {
        if(stakeHolders[msg.sender].stake == 0) addStakeHolder(msg.sender);
        stakeHolders[msg.sender].stake += toNanoToken(_stake);
   }

   function removeStake(uint256 _stake)
       public
   {
       (bool _isStakeHolder, ) = isStakeHolder(msg.sender);
       require(_isStakeHolder == true, "You are not a Stake holder yet. Please add some stakes first");
       require(stakeHolders[msg.sender].stake >= _stake, "Provided stake value is higher compared to existsing accounts's stake balance");
       stakeHolders[msg.sender].stake -= _stake;
       if(stakeHolders[msg.sender].stake == 0 && ABDKMathQuad.toUInt(stakeHolders[msg.sender].rewardBalance) == 0) removeStakeHolder(msg.sender);

   }

   function rewardBalanceOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return ABDKMathQuad.toUInt(stakeHolders[_stakeholder].rewardBalance);
   }

   function totalRewardBalance()
       public
       view
       returns(uint256)
   {
       bytes16 _totalRewards;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           _totalRewards = ABDKMathQuad.add(_totalRewards, stakeHolders[stakeHoldersList[s]].rewardBalance);
       }
       return ABDKMathQuad.toUInt(_totalRewards);
   }

    function calculateReward(address _stakeholder)
       public
       view
       returns(bytes16)
   {
       uint256 stakesPool = totalStakes();
       uint256 stakeHolderStake = stakeHolders[_stakeholder].stake;
       if(stakeHolderStake == 0) return ABDKMathQuad.fromInt(0);
       bytes16 stakePercentage = ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromUInt(stakeHolderStake), ABDKMathQuad.fromUInt(stakesPool)), ABDKMathQuad.fromUInt(100));
        
        return ABDKMathQuad.div(ABDKMathQuad.mul(dailyReward, stakePercentage) , ABDKMathQuad.fromUInt(100));
   }

    function getDailyReward() public view returns(uint256) {
        return ABDKMathQuad.toUInt(dailyReward);
    }

    function distributeRewards()
        public
        onlyOwner
    {
        for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
            address _stakeholder = stakeHoldersList[s];
            bytes16 reward = calculateReward(_stakeholder);
            poolBalance = ABDKMathQuad.sub(poolBalance, reward);

            
            if(s == stakeHoldersList.length - 1) {
                stakeHolders[_stakeholder].rewardBalance = ABDKMathQuad.add(reward, stakeHolders[_stakeholder].rewardBalance);
                uint256 totalRewards = totalRewardBalance();
                if(totalRewards < initialPoolBalance && (initialPoolBalance-totalRewards) < ABDKMathQuad.toUInt(reward)) {
                    uint256 remainder = initialPoolBalance - totalRewards;
                    stakeHolders[_stakeholder].rewardBalance = ABDKMathQuad.add(ABDKMathQuad.fromUInt(remainder), stakeHolders[_stakeholder].rewardBalance);
                }
                break;
            }
            
            stakeHolders[_stakeholder].rewardBalance = ABDKMathQuad.add(reward, stakeHolders[_stakeholder].rewardBalance);
        }
    }

    function withdrawReward()
        public
    {
        stakeHolders[msg.sender].rewardBalance = 0;
    }
}