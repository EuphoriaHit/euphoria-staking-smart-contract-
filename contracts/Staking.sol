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
  function totalSupply() external view returns (uint256);
}


contract Staking is Ownable {
    //This smart contract's reward distribution algorithm was based on this article
    //https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf

    using ABDKMathQuad for *;

    modifier contractExpired() {
        require((block.timestamp - startDay) / 86400 > contractDurationInDays && totalStakes == 0, "Error: Contract is not yet expired");
        _;
    }

    modifier contractNotExpired() {
        require((block.timestamp - startDay) / 86400 < contractDurationInDays, "Error: Contract has already expired");
        _;
    }

    constructor(uint256 _supplyPercentage, uint256 _durationInDays, address _tokenAddress) {
        require(_durationInDays > 0, "Error: Duration cannot be a zero value");
        require(_supplyPercentage > 0, "Error: Supply percentage cannot be a zero value");
        ERC20Interface = ERC20(_tokenAddress);
        contractDurationInDays = _durationInDays;
        bytes16 initialSupplyInBytes = ABDKMathQuad.div(ABDKMathQuad.fromUInt(ERC20Interface.totalSupply() * _supplyPercentage), ABDKMathQuad.fromUInt(100));
        initialSupply = ABDKMathQuad.toUInt(initialSupplyInBytes);
        dailyReward = ABDKMathQuad.div(initialSupplyInBytes, ABDKMathQuad.fromUInt(contractDurationInDays));
        startDay = block.timestamp - (block.timestamp % 86400);
    }

    
    ERC20 private ERC20Interface;
    uint256 private initialSupply;
    uint256 private contractDurationInDays;
    uint256 private startDay;
    uint256 private totalStakes; // T value in the Article Paper
    bytes16 private distributedRewards; // S value in the Article Paper
    bytes16 private dailyReward; // Amount of tokens that will be distributed among all users in 1 Day 
    uint256 private lastDay;
    uint256 private stakeHoldersCount;
    mapping(address => mapping(uint256 => bytes16)) private distributedRewardsSnapshot; // S0 value in the Article Paper
    mapping(address => mapping(uint256 => uint256)) private stake; // Keeps record of user's made stakings. Note that every new staking is considered as a seperate stake transaction
    mapping(address => uint256) private stakesCount;
    
    // <================================ EVENTS ================================>
    event StakeCreated(address indexed stakeHolder, uint256 indexed stake);

    event RewardsDistributed(uint256 indexed currentDay);

    event UnStaked(address indexed stakeHolder, uint256 withdrawAmount);

    event StakeHolderAdded(address indexed stakeHolder);

    event StakeHolderRemoved(address indexed stakeHolder);

    // <================================ INTERNAL FUNCTIONS ================================>

    function decimals() internal pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) internal pure returns(uint256) {
        return token * (10 ** decimals());
    }

    function balanceOfContract()
       internal
       view
       returns(uint256)
   {
       return ERC20Interface.balanceOf(address(this));
   }

    // <================================ PRIVATE FUNCTIONS ================================>

    function removeStakeHolder(address _stakeholder) private {
       require(_stakeholder != address(0), "Error: No zero address is allowed");
       bool _isStakeHolder = isStakeHolder(_stakeholder);
       require(_isStakeHolder == true, "Error: There is not any stake holder with provided address");

       if(_isStakeHolder) {
           for(uint i = 0; i < stakesCount[_stakeholder]; i++) {
               delete stake[_stakeholder][i];
               delete distributedRewardsSnapshot[_stakeholder][i];
           }
           delete stakesCount[_stakeholder];
           stakeHoldersCount -= 1;
       }

       emit StakeHolderRemoved(_stakeholder);
   }

    // <================================ PUBLIC FUNCTIONS ================================>

    function transferTokensToContract() public onlyOwner
    {
        ERC20Interface.transferFrom(msg.sender, address(this), initialSupply);
    }

   function isStakeHolder(address _address) public view returns(bool) {
       if(stake[_address][0] != 0 && stakesCount[_address] != 0) {
           return true;
       }
       return false;
   }

   function createStake(uint256 _stake)
       public
       contractNotExpired
   {
        address _stakeHolder = msg.sender;
        require(_stakeHolder != address(0), "Error: No zero address is allowed");
        require(_stake >= toNanoToken(10000), "Error: Minimal stake value is 10 000 euphoria tokens");
        if(!isStakeHolder(_stakeHolder)) stakeHoldersCount += 1;
        uint256 stakeId = stakesCount[_stakeHolder];
        ERC20Interface.transferFrom(_stakeHolder, address(this), _stake);
        stake[_stakeHolder][stakeId] = _stake;
        distributedRewardsSnapshot[_stakeHolder][stakeId] = distributedRewards;
       
        totalStakes += _stake;
        stakesCount[_stakeHolder] += 1;

        if(isStakeHolder(_stakeHolder)) emit StakeHolderAdded(_stakeHolder);
        emit StakeCreated(_stakeHolder, _stake);
   }

   function getStartDayOfContract()
        public
        view
    returns(uint256)
    {
        return startDay;
    }

    function getDurationOfContract()
        public
        view
    returns(uint256)
    {
        return contractDurationInDays;
    }

   function getBalanceOfContract()
       public
       onlyOwner
       view
       returns(uint256)
   {
       return ERC20Interface.balanceOf(address(this));
   }

    function finalize() public onlyOwner contractExpired {
        selfdestruct(payable(msg.sender));
    }

    function distributeRewards()
        public
        onlyOwner
        contractNotExpired
    {
        uint256 currentDay = (block.timestamp - startDay) / 86400;
        if(lastDay == currentDay) revert("Error: Rewards have already been distributed on this day!");
        if(totalStakes != 0) {
            distributedRewards = ABDKMathQuad.add(distributedRewards, ABDKMathQuad.div(dailyReward, ABDKMathQuad.fromUInt(totalStakes)));
        } else {
            revert("Error: There are currently no active stakes");
        }
        lastDay = currentDay;

        emit RewardsDistributed(currentDay);
    }

    function unStake()
        public
    {
        address _stakeHolder = msg.sender;
        uint256 userStakesCount = stakesCount[_stakeHolder];
        uint256 reward;
        uint256 totalDeposited;
        require(userStakesCount != 0, "Error: This user must be a stake holder");
        for(uint i = 0; i < userStakesCount; i++) {
            uint256 deposited = stake[msg.sender][i];
            reward += ABDKMathQuad.toUInt(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(deposited), ABDKMathQuad.sub(distributedRewards, distributedRewardsSnapshot[msg.sender][i])));
            totalDeposited += deposited;
        }
        require(reward > 0, "Error: User does not have any tokens in his balance");
        totalStakes -= totalDeposited;
        if(stakeHoldersCount == 1 && lastDay == contractDurationInDays) {
            ERC20Interface.transfer(_stakeHolder, balanceOfContract());
        } else {
            ERC20Interface.transfer(_stakeHolder, reward + totalDeposited);
        }
        removeStakeHolder(_stakeHolder);
        emit UnStaked(_stakeHolder, reward + totalDeposited);
    }
}