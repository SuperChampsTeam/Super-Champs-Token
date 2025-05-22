// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CliffLocker {
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

    IERC20 public immutable token;
    address public immutable admin;

    mapping(address => LockEvent[]) private lockHistory;
    mapping(address => ClaimEvent[]) private claimHistory;

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

    function lock(uint256 amount, uint256 durationInDays) external {
        require(amount > 0, "Amount must be > 0");
        uint256 UNIT = 100 * 1 ether; //TODO: comment this and uncomment below
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

    function claim(uint256 lockId) external {
        require(lockId < lockHistory[msg.sender].length, "Invalid lock ID");

        LockEvent storage le = lockHistory[msg.sender][lockId];
        require(!le.isClaimed, "Already claimed");
        require(block.timestamp >= le.endTime, "Tokens still locked");

        le.isClaimed = true;

        bool success = token.transfer(msg.sender, le.amount);
        require(success, "Transfer failed");

        claimHistory[msg.sender].push(ClaimEvent({
            lockId: lockId,
            amount: le.amount,
            claimedAt: block.timestamp
        }));

        emit Claimed(msg.sender, lockId, le.amount, block.timestamp);
    }

    // === View Functions ===

    function getLockHistory(uint256 offset) external view returns (LockEvent[] memory) {
        uint256 limit = 10;
        uint256 len = lockHistory[msg.sender].length;
        if (offset >= len) return new LockEvent[](0) ;

        uint256 end = offset + limit > len ? len : offset + limit;
        LockEvent[] memory result = new LockEvent[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = lockHistory[msg.sender][i];
        }
        return result;
    }

    function getClaimHistory(uint256 offset) external view returns (ClaimEvent[] memory) {
       uint256 limit = 10;
        uint256 len = claimHistory[msg.sender].length;
        if (offset >= len) return new ClaimEvent[](0) ;

        uint256 end = offset + limit > len ? len : offset + limit;
        ClaimEvent[] memory result = new ClaimEvent[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = claimHistory[msg.sender][i];
        }
        return result;
    }

    function getClaimable(uint256 lockId) external view returns (uint256) {
        if (lockId >= lockHistory[msg.sender].length) return 0;
        LockEvent storage le = lockHistory[msg.sender][lockId];
        if (!le.isClaimed && block.timestamp >= le.endTime) {
            return le.amount;
        }
        return 0;
    }
}
