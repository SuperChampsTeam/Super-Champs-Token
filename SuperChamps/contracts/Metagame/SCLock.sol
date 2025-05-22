
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CliffLocker {
    struct Lock {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool claimed;
    }

    struct LockEvent {
        uint256 lockId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
    }

    struct ClaimEvent {
        uint256 lockId;
        uint256 amount;
        uint256 claimedAt;
    }

    IERC20 public immutable token;
    address public immutable admin;

    mapping(address => Lock[]) public locks;
    mapping(address => LockEvent[]) public lockHistory;
    mapping(address => ClaimEvent[]) public claimHistory;

    event Locked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 startTime, uint256 endTime);
    event Claimed(address indexed user, uint256 indexed lockId, uint256 amount, uint256 claimedAt);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address _token, address _admin) {
        require(_token != address(0), "Token address is zero");
        require(_admin != address(0), "Admin address is zero");
        token = IERC20(_token);
        admin = _admin;
    }

    /// @notice Anyone (user or admin) locks their own tokens
    function lock(uint256 amount, uint256 durationInDays) external {
        require(amount > 0, "Amount must be > 0");
        uint256 UNIT = 100 * 1 ether;//TODO: comment this and uncomment below
        require(amount % UNIT == 0, "Amount must be multiple of 100");
        //uint256 UNIT = 10000 * 1 ether;
        //require(amount % UNIT == 0, "Amount must be multiple of 10000");
        require(durationInDays > 0, "Duration must be > 0");
        require(durationInDays % 1 == 0, "Duration must multiple of hours");
      //  require( durationInDays == 180 || durationInDays == 365 || durationInDays == 730, "Duration must be 6, 12, or 24 months");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (durationInDays * 1 days);

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        Lock memory newLock = Lock({
            amount: amount,
            startTime: startTime,
            endTime: endTime,
            claimed: false
        });

        locks[msg.sender].push(newLock);
        uint256 lockId = locks[msg.sender].length - 1;

        lockHistory[msg.sender].push(LockEvent({
            lockId: lockId,
            amount: amount,
            startTime: startTime,
            endTime: endTime
        }));

        emit Locked(msg.sender, lockId, amount, startTime, endTime);
    }

    /// @notice User claims unlocked tokens after cliff
    function claim(uint256 lockId) external {
        require(lockId < locks[msg.sender].length, "Invalid lock ID");

        Lock storage userLock = locks[msg.sender][lockId];
        require(!userLock.claimed, "Already claimed");
        require(block.timestamp >= userLock.endTime, "Tokens still locked");

        userLock.claimed = true;

        bool success = token.transfer(msg.sender, userLock.amount);
        require(success, "Transfer failed");

        claimHistory[msg.sender].push(ClaimEvent({
            lockId: lockId,
            amount: userLock.amount,
            claimedAt: block.timestamp
        }));

        emit Claimed(msg.sender, lockId, userLock.amount, block.timestamp);
    }

    // === View Functions ===

    function getLocks(address user) external view returns (Lock[] memory) {
        return locks[user];
    }

    function getLockHistory(address user) external view returns (LockEvent[] memory) {
        return lockHistory[user];
    }

    function getClaimHistory(address user) external view returns (ClaimEvent[] memory) {
        return claimHistory[user];
    }

    function getClaimable(address user, uint256 lockId) external view returns (uint256) {
        if (lockId >= locks[user].length) return 0;
        Lock storage l = locks[user][lockId];
        if (!l.claimed && block.timestamp >= l.endTime) {
            return l.amount;
        }
        return 0;
    }
}
