// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;//Q1

import "./CustomToken.sol";

contract ReferralSystem {
    CustomToken public immutable token;
    address public immutable backendWallet;
    uint256 public immutable rewardAmount;

    mapping(address => address) public referrerOf;
    mapping(address => address[]) private _referrals;
    mapping(address => bool) public hasJoined;

    event UserJoined(address indexed user, address indexed referrer);
    event RewardsDistributed(
        address indexed referrer,
        address indexed referee,
        uint256 rewardAmount
    );

    modifier onlyBackend() {
        require(msg.sender == backendWallet, "ReferralSystem: caller is not the backend");
        _;
    }

    constructor(
        address tokenAddress,
        address backend,
        uint256 reward
    ) {
        require(tokenAddress != address(0), "ReferralSystem: zero token address");
        require(backend != address(0), "ReferralSystem: zero backend address");
        require(reward > 0, "ReferralSystem: zero reward amount");

        token = CustomToken(tokenAddress);
        backendWallet = backend;
        rewardAmount = reward;
    }

    function join(address referrer) external {
        require(!hasJoined[msg.sender], "ReferralSystem: already joined");
        require(referrer != msg.sender, "ReferralSystem: self-referral not allowed");
        
        // Only check circular referral if referrer is not zero address
        if (referrer != address(0)) {
            require(
                referrerOf[referrer] != msg.sender,
                "ReferralSystem: circular referral detected"
            );
        }

        hasJoined[msg.sender] = true;
        referrerOf[msg.sender] = referrer;

        if (referrer != address(0)) {
            _referrals[referrer].push(msg.sender);
        }

        emit UserJoined(msg.sender, referrer);
    }

    function distributeRewards(address referee) external onlyBackend {
        require(hasJoined[referee], "ReferralSystem: user not joined");
        address referrer = referrerOf[referee];
        require(referrer != address(0), "ReferralSystem: no referrer");

        // Mint tokens to both parties
        token.mint(referee, rewardAmount);
        token.mint(referrer, rewardAmount);

        emit RewardsDistributed(referrer, referee, rewardAmount);
    }

    function getReferrals(address referrer) external view returns (address[] memory) {
        return _referrals[referrer];
    }

    function referralCount(address referrer) external view returns (uint256) {
        return _referrals[referrer].length;
    }
}