// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CliffLocker is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct LockEvent {
        uint256 lockId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool isClaimed;
    }

    struct ClaimEvent {
        uint256 lockId;
        uint256 amount;
        uint256 claimedAt;
    }

    IERC20 public token;

    mapping(address => LockEvent[]) private lockHistory;
    mapping(address => ClaimEvent[]) private claimHistory;

    event Locked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 startTime, uint256 endTime);
    event Claimed(address indexed user, uint256 indexed lockId, uint256 amount, uint256 claimedAt);
    event LockExtended(address indexed user, uint256 indexed lockId, uint256 newEndTime);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // prevents the logic contract from being initialized
    }

    function initialize(address _token) public initializer {
        require(_token != address(0), "Token address is zero");
        token = IERC20(_token);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function lock(uint256 amount, uint256 durationInSecs) external {
        require(amount > 0, "Amount must be > 0");
        require(durationInSecs > 0, "Duration must be > 0");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (durationInSecs * 1 seconds);
    

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        uint256 lockId = lockHistory[msg.sender].length;
        lockHistory[msg.sender].push(LockEvent({
            lockId: lockId,
            amount: amount,
            startTime: startTime,
            endTime: endTime,
            isClaimed: false
        }));

        emit Locked(msg.sender, lockId, amount, startTime, endTime);
    }

    /// @notice Extend the lock period
    function extendLock(uint256 lockId, uint256 additionalSecs) external {
        require(lockId < lockHistory[msg.sender].length, "Invalid lock ID");
        require(additionalSecs > 0, "Must extend by at least 1 Seconds");

        LockEvent storage l = lockHistory[msg.sender][lockId];
        require(!l.isClaimed, "Already claimed");

        l.endTime += additionalSecs * 1 seconds;

        emit LockExtended(msg.sender, lockId, l.endTime);
    }

    function claim(uint256 lockId) external {
        require(lockId < lockHistory[msg.sender].length, "Invalid lock ID");

        LockEvent storage l = lockHistory[msg.sender][lockId];
        require(!l.isClaimed, "Already claimed");
        require(block.timestamp >= l.endTime, "Tokens still locked");

        l.isClaimed = true;

        bool success = token.transfer(msg.sender, l.amount);
        require(success, "Transfer failed");

        claimHistory[msg.sender].push(ClaimEvent({
            lockId: lockId,
            amount: l.amount,
            claimedAt: block.timestamp
        }));

        emit Claimed(msg.sender, lockId, l.amount, block.timestamp);
    }

    // === View Functions ===

    function getLockHistory(address user) external view returns (LockEvent[] memory) {
        return lockHistory[user];
    }

    function getClaimHistory(address user) external view returns (ClaimEvent[] memory) {
        return claimHistory[user];
    }

    function getClaimable(address user, uint256 lockId) external view returns (uint256) {
        if (lockId >= lockHistory[user].length) return 0;
        LockEvent storage l = lockHistory[user][lockId];
        if (!l.isClaimed && block.timestamp >= l.endTime) {
            return l.amount;
        }
        return 0;
    }
}
