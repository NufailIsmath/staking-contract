// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Staking is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    IERC20Upgradeable public token;
    uint256 public stakingDuration; // Duration in seconds
    uint256 public stakingStartTime;
    bool public autoCompound;

    struct Staker {
        uint256 amount;
        uint256 stakedTime;
    }

    mapping(address => Staker) public stakers;

    event Staked(address staker, uint256 amount, uint256 timestamp);
    event Withdraw(address staker, uint256 amount, uint256 timestamp);

    modifier onlyStaked() {
        require(stakers[msg.sender].amount > 0, "Staking: No Staked Amount!");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 _stakingDuration,
        uint256 _stakingStartTime,
        bool _autoCompound,
        address _token
    ) public initializer {
        stakingDuration = _stakingDuration;
        stakingStartTime = _stakingStartTime;
        autoCompound = _autoCompound;
        token = IERC20Upgradeable(_token);

        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function stake(uint256 amount) public {
        require(
            block.timestamp > stakingStartTime,
            "Staking: Staking start time has not met!"
        );
        require(amount > 0, "Staking: Amount must be greater than 0!");
        require(stakers[msg.sender].amount == 0, "Staking: Already Staked!");
        require(
            token.balanceOf(msg.sender) >= amount,
            "Staking: Insufficient Balance!"
        );

        token.transferFrom(msg.sender, address(this), amount);
        stakers[msg.sender] = Staker(amount, block.timestamp);

        emit Staked(msg.sender, amount, block.timestamp);
    }

    function withdrawStake() public onlyStaked {
        Staker storage staker = stakers[msg.sender];
        require(
            block.timestamp >= staker.stakedTime + stakingDuration,
            "Staking: Staking Period Not Over!"
        );

        uint256 withdrawAmount = staker.amount;
        staker.amount = 0;
        delete stakers[msg.sender];

        token.transfer(msg.sender, withdrawAmount);
        emit Withdraw(msg.sender, withdrawAmount, block.timestamp);
    }

    function viewStake() public view returns (Staker memory) {
        return stakers[msg.sender];
    }

    function compoundStake() public onlyStaked {
        Staker storage staker = stakers[msg.sender];
        require(
            block.timestamp >= staker.stakedTime + stakingDuration,
            "Staking: Staking Period Not Over!"
        );
        require(autoCompound, "Staking: Auto Compound Not Enabled!");

        uint256 reward = computeReward(msg.sender);
        require(reward > 0, "Staking: No Reward To Compound!");

        staker.stakedTime = block.timestamp;
        token.mint(address(this), reward);
        staker.amount += reward;

        emit Staked(msg.sender, reward, staker.stakedTime);
    }

    function computeReward(
        address stakerAddress
    ) public view returns (uint256) {
        Staker storage staker = stakers[stakerAddress];

        uint256 elapsed = block.timestamp - staker.stakedTime;
        uint256 rewards = (staker.amount * elapsed) / stakingDuration;

        return rewards;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
