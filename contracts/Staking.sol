// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Ownable.sol";
import "./ABDKMathQuad.sol";
import "./Pausable.sol";

interface ERC20 {
  function balanceOf(address owner) external view returns (uint);
  function allowance(address owner, address spender) external view returns (uint);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint value) external returns (bool); 
}


contract Staking is Ownable, Pausable {
    //This smart contract's reward distribution algorithm was based on this article
    //https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf

    using ABDKMathQuad for *;

    modifier contractExpired() {
        require((block.timestamp - startDay) / 86400 > contractDurationInDays && totalStakes == 0, "Contract is not yet expired");
        _;
    }

    modifier contractNotExpired() {
        require((block.timestamp - startDay) / 86400 < contractDurationInDays, "Contract has already expired");
        _;
    }

    constructor(uint256 _supply, uint256 _durationInDays, address _tokenAddress) {
        require(_durationInDays > 0, "Duration cannot be zero or negative value");
        require(_supply > 0, "Supply cannot be zero or negative value");
        ERC20Interface = ERC20(_tokenAddress);
        contractDurationInDays = _durationInDays;
        initialPoolBalance = _supply;
        dailyReward = dailyReward = ABDKMathQuad.div(ABDKMathQuad.fromUInt(initialPoolBalance), ABDKMathQuad.fromUInt(contractDurationInDays));
        startDay = block.timestamp - (block.timestamp % 86400);
    }

    
    ERC20 private ERC20Interface;
    uint256 private initialPoolBalance;
    uint256 private contractDurationInDays;
    uint256 private startDay;
    uint256 private totalStakes; // T value in the Article Paper
    bytes16 private distributedRewards; // S value in the Article Paper
    bytes16 private dailyReward; // Amount of tokens that will be distributed among all users in 1 Day 
    uint256 private lastDay;
    mapping(address => mapping(uint256 => bytes16)) private distributedRewardsSnapshot; // S0 value in the Article Paper
    mapping(address => mapping(uint256 => uint256)) private stake; // Keeps record of user's made stakings. Note that every new staking is considered as a seperate stake transaction
    mapping(address => uint256) private stakesCount;
    
    // <================================ EVENTS ================================>
    event stakeCreated(address indexed stakeHolder, uint256 indexed stake);

    event rewardsDistributed(uint256 indexed currentDay);

    event unStaked(address indexed stakeHolder, uint256 withdrawAmount);

    event stakeHolderAdded(address indexed stakeHolder);

    event stakeHolderRemoved(address indexed stakeHolder);

    // <================================ INTERNAL FUNCTIONS ================================>

    function decimals() public pure returns(uint8) {
        return 3;
    }

    function toNanoToken(uint256 token) public pure returns(uint256) {
        return token * (10 ** decimals());
    }

    function isContractExpired() internal view returns(bool) {
        return ((block.timestamp - startDay) / 86400) > 1460;
    }

    // <================================ PUBLIC FUNCTIONS ================================>

    function transferTokensToContract() public onlyOwner whenNotPaused
    {
        ERC20Interface.transferFrom(msg.sender, address(this), initialPoolBalance);
    }

   function isStakeHolder(address _address) public view returns(bool) {
       if(stake[_address][0] != 0 && stakesCount[_address] != 0) {
           return true;
       }
       return false;
   }

   function removeStakeHolder(address _stakeholder) public {
       require(_stakeholder != address(0), "Error: No zero address is allowed");
       bool _isStakeHolder = isStakeHolder(_stakeholder);
       require(_isStakeHolder == true, "Error: There is not any stake holder with provided address");

       if(_isStakeHolder) {
           for(uint i = 0; i < stakesCount[_stakeholder]; i++) {
               delete stake[_stakeholder][i];
               delete distributedRewardsSnapshot[_stakeholder][i];
           }
           delete stakesCount[_stakeholder];
       }

       emit stakeHolderRemoved(_stakeholder);
   }

   function createStake(uint256 _stake)
       public
       whenNotPaused
       contractNotExpired
   {
        address _stakeHolder = msg.sender;
        require(_stakeHolder != address(0), "Error: No zero address is allowed");
        require(_stake >= toNanoToken(10000), "Error: Minimal stake value is 10 000 euphoria tokens");
        uint256 stakeId = stakesCount[_stakeHolder];
        ERC20Interface.transferFrom(_stakeHolder, address(this), _stake);
        stake[_stakeHolder][stakeId] = _stake;
        distributedRewardsSnapshot[_stakeHolder][stakeId] = distributedRewards;
       
        totalStakes += _stake;
        stakesCount[_stakeHolder] += 1;

        if(isStakeHolder(_stakeHolder)) emit stakeHolderAdded(_stakeHolder);
        emit stakeCreated(_stakeHolder, _stake);
   }

    function balanceOfContract()
       internal
       view
       returns(uint256)
   {
       return ERC20Interface.balanceOf(address(this));
   }

   function getStartDay()
        public
        view
    returns(uint256)
    {
        return startDay;
    }

    function getContractDuration()
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

        emit rewardsDistributed(currentDay);
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
        ERC20Interface.transfer(_stakeHolder, reward + totalDeposited);
        removeStakeHolder(_stakeHolder);
        emit unStaked(_stakeHolder, reward + totalDeposited);
    }
}