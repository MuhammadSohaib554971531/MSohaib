// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;//Q2

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./LPTokenNFT.sol";

contract StakingContract {
    IERC20 public stakingToken;
    LPTokenNFT public lpNFT;
    LPTokenNFT public achievementNFT;
 
    bool private _locked;

    struct Staker {
        uint256 amountStaked;
        uint256 score;
        uint256 lastUpdate;
        uint256 nftId;
        bool hasNFT;
        uint256 highestTierReached;
    }

    mapping(address => Staker) public stakers;
    uint256[] public tierThresholds = [1000 ether, 5000 ether, 10000 ether];

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event TierReached(address indexed user, uint256 tier, uint256 achievementTokenId);

    constructor(address _stakingToken, address _lpNFT, address _achievementNFT) {
        require(_stakingToken != address(0), "Invalid token address");
        require(_lpNFT != address(0), "Invalid NFT address");
        require(_achievementNFT != address(0), "Invalid achievement NFT address");
        
        stakingToken = IERC20(_stakingToken);
        lpNFT = LPTokenNFT(_lpNFT);
        achievementNFT = LPTokenNFT(_achievementNFT);
    }


    modifier noReentrant() {
        require(!_locked, "No reentrancy");
        _locked = true;
        _;
        _locked = false;
    }

    function stake(uint256 amount) external noReentrant {
        require(amount > 0, "Cannot stake 0");
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        Staker storage user = stakers[msg.sender];
        _updateScore(msg.sender);

        user.amountStaked += amount;
        user.lastUpdate = block.timestamp;

        string memory metadata = _generateMetadata(user.amountStaked, user.score);

        if (!user.hasNFT) {
            uint256 tokenId = lpNFT.mint(msg.sender, metadata);
            user.nftId = tokenId;
            user.hasNFT = true;
        } else {
            lpNFT.updateURI(user.nftId, metadata);
        }

        _checkTiers(msg.sender);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external noReentrant {
        Staker storage user = stakers[msg.sender];
        require(user.amountStaked >= amount, "Insufficient stake");

        _updateScore(msg.sender);
        user.amountStaked -= amount;
        user.lastUpdate = block.timestamp;

        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");

        string memory metadata = _generateMetadata(user.amountStaked, user.score);
        lpNFT.updateURI(user.nftId, metadata);

        emit Withdrawn(msg.sender, amount);
    }

    function _updateScore(address userAddr) internal {
        Staker storage user = stakers[userAddr];
        if (user.lastUpdate == 0) {
            user.lastUpdate = block.timestamp;
            return;
        }

        uint256 duration = block.timestamp - user.lastUpdate;
        user.score += user.amountStaked * duration;
    }

    function _checkTiers(address userAddr) internal {
        Staker storage user = stakers[userAddr];
        for (uint i = user.highestTierReached; i < tierThresholds.length; i++) {
            if (user.score >= tierThresholds[i]) {
                user.highestTierReached = i + 1; // 1-based index
                string memory tierMetadata = _generateTierMetadata(tierThresholds[i]);
                uint256 achievementTokenId = achievementNFT.mint(userAddr, tierMetadata);
                emit TierReached(userAddr, tierThresholds[i], achievementTokenId);
            } else {
                break;
            }
        }
    }

    function _generateMetadata(uint256 staked, uint256 score) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"Staking Position",',
                '"description":"NFT representing staked tokens and rewards",',
                '"attributes":[',
                '{"trait_type":"Staked Amount","value":', _uintToStr(staked), '},',
                '{"trait_type":"Score","value":', _uintToStr(score), '}',
                ']}'
            )
        );
    }

    function _generateTierMetadata(uint256 tier) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"Staking Achievement",',
                '"description":"Achievement for reaching staking tier",',
                '"attributes":[',
                '{"trait_type":"Tier","value":"', _uintToStr(tier), '"}',
                ']}'
            )
        );
    }

    function _uintToStr(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}