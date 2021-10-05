// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//import {SafeMath} from "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./ABDKMathQuad.sol";
import "./ABDKMath64x64.sol";

contract Staking is Ownable {

   /**
    * @notice The constructor for the Staking Token.
    * @param _supply The amount of tokens to mint on construction.
    */
   /*
   constructor(address _owner, uint256 _supply)
       public
   {
       _mint(_owner, _supply);
   }
    */

    constructor(uint256 _supply) {
        poolBalance = _supply;
        dailyReward = _supply / (365 * 4);
    }

    /**
    * @notice We usually require to know who are all the stakeholders.
    */

    struct Stakeholder {
        address holderAddress;
        uint256 rewardBalance;
        uint256 stake;
    }

    address[] internal stakeHoldersList;
    mapping(address => Stakeholder) stakeHolders;
    
    //uint256 private stakesPool;
    uint256 private poolBalance;
    uint256 private dailyReward;
    //mapping(address => uint256) internal stakes;
    //mapping(address => uint256) internal balances;
    //mapping(address => uint256) internal rewards;


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

    /**
    * @notice A method to retrieve the stake for a stakeholder.
    * @param _stakeholder The stakeholder to retrieve the stake for.
    * @return uint256 The amount of wei staked.
    */
   function stakeOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return stakeHolders[_stakeholder].stake; //stakes[_stakeholder];
   }

   /**
    * @notice A method to the aggregated stakes from all stakeholders.
    * @return uint256 The aggregated stakes from all stakeholders.
    */
   function totalStakes()
       public
       view
       returns(uint256)
   {
       uint256 _totalStakes = 0;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           //_totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
            _totalStakes += stakeHolders[stakeHoldersList[s]].stake;
       }
       
       return _totalStakes;
   }

   /**
    * @notice A method for a stakeholder to create a stake.
    * @param _stake The size of the stake to be created.
    */
   function createStake(uint256 _stake)
       public
   {
       //_burn(msg.sender, _stake);
       //if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
       //stakes[msg.sender] = stakes[msg.sender].add(_stake);
        if(stakeHolders[msg.sender].stake == 0) addStakeHolder(msg.sender);
        stakeHolders[msg.sender].stake += _stake;
   }

   /**
    * @notice A method for a stakeholder to remove a stake.
    * @param _stake The size of the stake to be removed.
    */
   function removeStake(uint256 _stake)
       public
   {
       stakeHolders[msg.sender].stake -= _stake;
       if(stakeHolders[msg.sender].stake == 0) removeStakeHolder(msg.sender);
       //stakes[msg.sender] = stakes[msg.sender].sub(_stake);
       //if(stakes[msg.sender] == 0) removeStakeHolder(msg.sender);
       //_mint(msg.sender, _stake);
   }

    /**
    * @notice A method to allow a stakeholder to check his rewards.
    * @param _stakeholder The stakeholder to check rewards for.
    */
   function rewardBalanceOf(address _stakeholder)
       public
       view
       returns(uint256)
   {
       return stakeHolders[_stakeholder].rewardBalance;
   }

   /**
    * @notice A method to the aggregated rewards from all stakeholders.
    * @return uint256 The aggregated rewards from all stakeholders.
    */
   function totalRewardBalance()
       public
       view
       returns(uint256)
   {
       uint256 _totalRewards = 0;
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           //_totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
           _totalRewards += stakeHolders[stakeHoldersList[s]].rewardBalance;
       }
       return _totalRewards;
   }

   /**
    * @notice A simple method that calculates the rewards for each stakeholder.
    * @param _stakeholder The stakeholder to calculate rewards for.
    */
   function calculateReward(address _stakeholder)
       public
       view
       returns(uint256)
   {
       uint256 stakesPool = totalStakes();
        uint256 stakePercentage = (stakeHolders[_stakeholder].stake / stakesPool) * 100;
        
        return (dailyReward * stakePercentage) / 100;
   }

   /**
    * @notice A method to distribute rewards to all stakeholders.
    */
   function distributeRewards()
       public
       onlyOwner
   {
       for (uint256 s = 0; s < stakeHoldersList.length; s += 1){
           address stakeholder = stakeHoldersList[s];
           uint256 reward = calculateReward(stakeholder);
           stakeHolders[stakeholder].rewardBalance += reward;
       }
   }

   /**
    * @notice A method to allow a stakeholder to withdraw his rewards.
    */
   function withdrawReward()
       public
   {
       //uint256 reward = stakeHolders[msg.sender].rewardBalance;
       stakeHolders[msg.sender].rewardBalance = 0;
       //_mint(msg.sender, reward);
   }
}