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
        dailyReward = ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromUInt(_supply), ABDKMathQuad.fromUInt(365*4)), fromUInt(10 ** decimals()));
    }

    struct Stakeholder {
        address holderAddress;
        bytes16 rewardBalance;
        bytes16 stake;
    }

    address[] internal stakeHoldersList;
    mapping(address => Stakeholder) stakeHolders;

    bytes16 private poolBalance;
    bytes16 private dailyReward;

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
       (bool _isStakeholder, ) = isStakeHolder(_stakeholder);
       if(!_isStakeholder) {
           stakeHolders[_stakeholder].holderAddress = _stakeholder;
           stakeHoldersList.push(_stakeholder);
       }
   }

   function removeStakeHolder(address _stakeholder) public {
       (bool _isStakeholder, uint256 sHolderId) = isStakeHolder(_stakeholder);
       if(_isStakeholder) {
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

   function createStake(uint256 _stake)
       public
   {
        if(stakeHolders[msg.sender].stake == 0) addStakeHolder(msg.sender);
        stakeHolders[msg.sender].stake += _stake;
   }

   function removeStake(uint256 _stake)
       public
   {
       stakeHolders[msg.sender].stake -= _stake;
       if(stakeHolders[msg.sender].stake == 0) removeStakeHolder(msg.sender);

   }

   function rewardBalanceOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return stakeHolders[_stakeholder].rewardBalance;
   }

   function totalRewardBalance()
       public
       view
       returns(uint256)
   {
       uint256 _totalRewards = 0;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           _totalRewards += stakeHolders[stakeHoldersList[s]].rewardBalance;
       }
       return _totalRewards;
   }

    function calculateReward(address _stakeholder)
       public
       view
       returns(bytes16)
   {
       uint256 stakesPool = totalStakes();
       bytes16 stakePercentage = ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromUInt(stakeHolders[_stakeholder].stake, ABDKMathQuad.fromUInt(stakePool))), ABDKMathQuad.fromUInt(100));
        //uint256 stakePercentage = (stakeHolders[_stakeholder].stake / stakesPool) * 100;
        
        return ABDKMathQuad.div(ABDKMathQuad.mul(dailyReward, stakePercentage) , ABDKMathQuad.fromUInt(100));
        //return (dailyReward * stakePercentage) / 100;
   }

/*
   function calculateReward(address _stakeholder)
       public
       view
       returns(uint256)
   {
       uint256 stakesPool = totalStakes();
        uint256 stakePercentage = (stakeHolders[_stakeholder].stake / stakesPool) * 100;
        
        return (dailyReward * stakePercentage) / 100;
   }
*/
   function distributeRewards()
       public
       onlyOwner
   {
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           address stakeholder = stakeHoldersList[s];
           bytes16 reward = calculateReward(stakeholder);// NEEDS TO BE CHANGED
           stakeHolders[stakeholder].rewardBalance += reward;
       }
   }

   function withdrawReward()
       public
   {
       stakeHolders[msg.sender].rewardBalance = 0;
   }
}