// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ISCLockOld {
    struct LockEvent {
        uint256 lockId;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool isClaimed;
    }

    function getLockHistory(address user) external view returns (LockEvent[] memory);
}

contract SCLock is Initializable, OwnableUpgradeable {
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
    mapping(address => bool) public isLockImported; 

    event Locked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 startTime, uint256 endTime);
    event Claimed(address indexed user, uint256 indexed lockId, uint256 amount, uint256 claimedAt);
    event LockExtended(address indexed user, uint256 indexed lockId, uint256 newEndTime);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token) public initializer {
        require(_token != address(0), "Token address is zero");
        token = IERC20(_token);
        __Ownable_init(msg.sender);
    }

    function lock(uint256 amount, uint256 durationInSecs) external {
        require(amount > 0, "Amount must be > 0");
        require(durationInSecs > 0, "Duration must be > 0");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + durationInSecs;

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

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

    function extendLock(uint256 lockId, uint256 additionalSecs) external {
        require(lockId < lockHistory[msg.sender].length, "Invalid lock ID");
        require(additionalSecs > 0, "Must extend by at least 1 second");

        LockEvent storage l = lockHistory[msg.sender][lockId];
        require(!l.isClaimed, "Already claimed");

        l.endTime += additionalSecs;

        emit LockExtended(msg.sender, lockId, l.endTime);
    }

    function claim(uint256 lockId) external {
        require(lockId < lockHistory[msg.sender].length, "Invalid lock ID");

        LockEvent storage l = lockHistory[msg.sender][lockId];
        require(!l.isClaimed, "Already claimed");
        require(block.timestamp >= l.endTime, "Tokens still locked");

        l.isClaimed = true;

        require(token.transfer(msg.sender, l.amount), "Transfer failed");

        claimHistory[msg.sender].push(ClaimEvent({
            lockId: lockId,
            amount: l.amount,
            claimedAt: block.timestamp
        }));

        emit Claimed(msg.sender, lockId, l.amount, block.timestamp);
    }

    /// @notice Admin-only import from older contract
    function importLocksFromOldContract(address oldContract, address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (isLockImported[user]) {
                continue;
            }
            ISCLockOld.LockEvent[] memory oldLocks = ISCLockOld(oldContract).getLockHistory(user);

            for (uint256 j = 0; j < oldLocks.length; j++) {
                ISCLockOld.LockEvent memory oldLock = oldLocks[j];

                lockHistory[user].push(LockEvent({
                    lockId: lockHistory[user].length,
                    amount: oldLock.amount,
                    startTime: oldLock.startTime,
                    endTime: oldLock.endTime,
                    isClaimed: oldLock.isClaimed
                }));

                emit Locked(user, lockHistory[user].length - 1, oldLock.amount, oldLock.startTime, oldLock.endTime);
            }
            isLockImported[user] = true;
        }
    }


    function hasImportedLocks(address user) external view returns (bool) {
        return isLockImported[user];
    }


    // === View Functions ===

    function getLockHistory(address user) external view returns (LockEvent[] memory) {
        return lockHistory[user];
    }

    function getClaimHistory(address user) external view returns (ClaimEvent[] memory) {
        return claimHistory[user];
    }

    function getLockHistoryPaginated(address user, uint256 offset, uint256 limit) external view returns (LockEvent[] memory) {
        LockEvent[] storage history = lockHistory[user];
        uint256 total = history.length;
        if (offset >= total) return new LockEvent[](0) ;

        uint256 end = offset + limit;
        if (end > total) end = total;

        LockEvent[] memory result = new LockEvent[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = history[i];
        }
        return result;
    }

    function getClaimHistoryPaginated(address user, uint256 offset, uint256 limit) external view returns (ClaimEvent[] memory) {
        ClaimEvent[] storage history = claimHistory[user];
        uint256 total = history.length;
        if (offset >= total) return new ClaimEvent[](0) ;

        uint256 end = offset + limit;
        if (end > total) end = total;

        ClaimEvent[] memory result = new ClaimEvent[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = history[i];
        }
        return result;
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
