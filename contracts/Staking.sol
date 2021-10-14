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

    constructor(uint256 _supply, address _owner) {
        ERC20Interface = ERC20(_owner);
        poolBalance = ABDKMathQuad.fromUInt(_supply);
        initialPoolBalance = _supply;
        dailyReward = dailyReward = ABDKMathQuad.div(poolBalance, ABDKMathQuad.fromUInt(10));
        startDay = block.timestamp - (block.timestamp % 86400);
    }

    
    ERC20 private ERC20Interface;
    bytes16 private dailyReward; // dailyReward that will be shared between users based on their overall percentage everyday
    bytes16 private poolBalance; // Amount of left NanoTokens value that is being spread within 4 years
    uint256 private initialPoolBalance; // Amount of initial NanoTokens value
    uint256 private startDay; // Timestamp of date when the smart contract has been deployed
    mapping(address => uint256) stakes; // Total amount of stakes of user for the current time
    mapping(uint256 => uint256) totalStakesAtDay; // Stores total amount of stakes this contract had on specific day. Used for final calculation
    mapping(address => mapping(uint256 => uint256)) stakeHolderStakeAtDay; // Stores exact amount of stakes user had on specific day. Used for final calculation
    uint256[] internal stakesChangeDays; //This variable holds the number of days when the user's made any interactions. Like createStake or unStake
    address[] internal stakeHolders;
    

    // <================================ INTERNAL FUNCTIONS ================================>

    function decimals() public pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) public pure returns(uint256) {
        return token * (10 ** decimals());
    }

    // <================================ PUBLIC FUNCTIONS ================================>

    function transferTokensToContract() public onlyOwner
    {
        ERC20Interface.transferFrom(msg.sender, address(this), initialPoolBalance);
    }

   function isStakeHolder(address _address) public view returns(bool, uint256) {
       address[] memory localStakeHolders = stakeHolders;
       for(uint256 sHolderId = 0; sHolderId < stakeHolders.length; sHolderId++) {
           if(_address == localStakeHolders[sHolderId]) return (true, sHolderId);
       }
       return (false, 0);
   }

   function addStakeHolder(address _stakeholder) public {
       require(_stakeholder != address(0), "No zero address is allowed");
       (bool _isStakeHolder, ) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == false, "Stake holder with provided address already exists");
       if(!_isStakeHolder) {
           stakeHolders.push(_stakeholder);
       }
   }

   function removeStakeHolder(address _stakeholder) public {
       require(_stakeholder != address(0), "No zero address is allowed");
       (bool _isStakeHolder, uint256 sHolderId) = isStakeHolder(_stakeholder);
       require(_isStakeHolder == true, "There is not any stake holder with provided address");

       if(_isStakeHolder) {
           delete stakes[_stakeholder];
           stakeHolders[sHolderId] = stakeHolders[stakeHolders.length - 1];
           stakeHolders.pop();
       }
   }

   function createStake(uint256 _stake)
       public
   {
        uint256 daysSinceStart = (block.timestamp - startDay) / 86400;
        require(msg.sender != address(0), "No zero address is allowed");
        require(_stake >= toNanoToken(10000), "Minimal stake value is 10 000 euphoria tokens");
        require(ABDKMathQuad.toUInt(poolBalance) > 0, "Pool is empty. System does not accept any new stakes");
        if(stakes[msg.sender] == 0) addStakeHolder(msg.sender);
        ERC20Interface.transferFrom(msg.sender, address(this), _stake);
        stakes[msg.sender] += _stake;
        stakeHolderStakeAtDay[msg.sender][daysSinceStart] = stakes[msg.sender];
        
        if(stakesChangeDays.length == 0) {
            stakesChangeDays.push(daysSinceStart);
            totalStakesAtDay[daysSinceStart] = _stake;
            return;    
        } else if(stakesChangeDays[stakesChangeDays.length-1] != daysSinceStart) {
            totalStakesAtDay[daysSinceStart] = totalStakesAtDay[stakesChangeDays[stakesChangeDays.length-1]] + _stake;
            stakesChangeDays.push(daysSinceStart);
            return;
        }
        
        totalStakesAtDay[daysSinceStart] += _stake;
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

    function calculateFinalReward(address _stakeHolder)
        public
        returns(uint256)
    {
        uint256 daysSinceStart = (block.timestamp - startDay) / 86400;
        bytes16 totalStakes;
        bytes16 stakeHolderStake;
        bytes16 finalReward;
        for(uint i = 0; i < stakesChangeDays.length; i++) {
            uint256 day = stakesChangeDays[i];
            if(totalStakesAtDay[day] != 0) totalStakes = ABDKMathQuad.fromUInt( totalStakesAtDay[day] ); //totalStakesAtDay[day]; 
            if(stakeHolderStakeAtDay[_stakeHolder][day] != 0 ) stakeHolderStake = ABDKMathQuad.fromUInt( stakeHolderStakeAtDay[_stakeHolder][day] ); //stakeHolderStakeAtDay[_stakeHolder][day];
            
            uint256 daysInARow;
            if(stakesChangeDays.length-1 > i) {
                daysInARow = stakesChangeDays[i+1] - stakesChangeDays[i];
            } else if(stakesChangeDays[stakesChangeDays.length-1] < daysSinceStart) {
                daysInARow = daysSinceStart - stakesChangeDays[stakesChangeDays.length-1];
            } else {
                daysInARow = 1;
            }
            
            bytes16 stakePercentage = ABDKMathQuad.div(stakeHolderStake, totalStakes);
            finalReward = ABDKMathQuad.add(finalReward, ABDKMathQuad.mul( ABDKMathQuad.mul(dailyReward, stakePercentage), ABDKMathQuad.fromUInt(daysInARow) )) ;
            delete stakeHolderStakeAtDay[_stakeHolder][day];
        }
        
        return ABDKMathQuad.toUInt(finalReward); //finalReward;
    }

    function unStake()
        public
        returns(uint256)
    {
        require(stakes[msg.sender] != 0, "This user must be a stake holder");
        uint256 daysSinceStart = (block.timestamp - startDay) / 86400;
        uint256 reward = calculateFinalReward(msg.sender);
        require(reward > 0, "User does not have any tokens in his balance");
        totalStakesAtDay[daysSinceStart] = totalStakesAtDay[stakesChangeDays[stakesChangeDays.length-1]] - stakes[msg.sender];
        
        if(stakesChangeDays[stakesChangeDays.length-1] != daysSinceStart) {
            stakesChangeDays.push(daysSinceStart);
        }
        removeStakeHolder(msg.sender);
        return reward;
    }
}