// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";

/**
 * @title TheRewarderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 */
contract TheRewarderPool {

    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;

    uint256 public lastSnapshotIdForRewards;
    // 上次
    uint256 public lastRecordedSnapshotTimestamp;

    
    mapping(address => uint256) public lastRewardTimestamps;

    // Token deposited into the pool by users

    DamnValuableToken public immutable liquidityToken;

    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    // 计算
    AccountingToken public accToken;
    
    // Token in which rewards are issued
    //
    RewardToken public immutable rewardToken;

    // Track number of rounds
    uint256 public roundNumber;

    
    constructor(address tokenAddress) {
        // Assuming all three tokens have 18 decimals

        liquidityToken = DamnValuableToken(tokenAddress);
        accToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance

     */

    function deposit(uint256 amountToDeposit) external {
        // 通过闪电贷把款存进去 
        require(amountToDeposit > 0, "Must deposit tokens");
        // 挖 
        accToken.mint(msg.sender, amountToDeposit);
        //分发奖励
        distributeRewards();

        require(
             //转到合约里
            liquidityToken.transferFrom(msg.sender, address(this), amountToDeposit)
        );
    }
/*
 // 通过闪电贷把款存进去 然后还回去 
  是为了获取奖励 

*/
    function withdraw(uint256 amountToWithdraw) external {
        //   销毁之前     accToken.mint(msg.sender, amountToDeposit);
        accToken.burn(msg.sender, amountToWithdraw);
        // 提现 
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }

    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

// 新的一轮
        if(isNewRewardsRound()) {
            // 
            _recordSnapshot();
        }        
        
        //  上一轮
        uint256 totalDeposits = accToken.totalSupplyAt(lastSnapshotIdForRewards);
        // 上一轮
        uint256 amountDeposited = accToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {

            rewards = (amountDeposited * 100 * 10 ** 18) / totalDeposits;

   // 奖励大于0 
            if(rewards > 0 && !_hasRetrievedReward(msg.sender)) {

                rewardToken.mint(msg.sender, rewards);

                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;     
    }

// 做个snap操作
    function _recordSnapshot() private {
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }


    function _hasRetrievedReward(address account) private view returns (bool) {
        return (

            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp &&
            lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        // 是否是新的一轮
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}
