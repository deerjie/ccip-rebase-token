// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 * @title RebaseToken
 * @author cedar
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 */
contract RebaseToken is ERC20, Ownable, AccessControl,IRebaseToken {
    // State variables
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 public s_interestRate = 5e10; // 利率
    mapping(address => uint256) public s_userInterestRate; // 用户利率
    mapping(address => uint256) public s_userLastUpdatedTimestamp; // 用户上次更新时间
    uint256 public constant PRECISION_FACTOR = 1e18; // 精度因子

    // Events
    event InterestRateSet(uint256 newInterestRate);
    
   // Error
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 s_interestRate, uint256 _newInterestRate);
    
    

    
    constructor() ERC20("REBASE_TOKEN","RBT") Ownable(msg.sender) {}

    /**
     * 给账户设置不同角色权限
     * @param account 账户地址
     */
    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /**
     * 初始化利率
     * @param _newInterestRate 利率
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // 利率只能降低
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * 铸造token
     * @param account token持有者账户
     * @param value token数量
     */
    function mint(address account, uint256 value, uint256 _userInterestRate) external override {
        // 更新用户的余额（本金+利息）
        _mintAccruedInterest(account);
        // 更新用户的利率
        s_userInterestRate[account] = _userInterestRate;
        _mint(account, value);
    }

    /**
     * @notice 获取当前利率
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice 获取当前利率
     * @param account 账户地址
     */
    function getUserInterestRate(address account) external view returns (uint256) {
        return s_userInterestRate[account];
    }


    /**
     * @dev  将用户的累计利息加入本金余额。此函数为用户铸造自他们上次转移或桥接代币以来累计的利息。
     * @param _user 用户获得利息的地址
     */
    function _mintAccruedInterest(address _user) internal {
        // 调用ERC20的balanceOf函数来获取用户的本金余额
        uint256 previousPrincipalBalance = super.balanceOf(_user);

        // 获取计算利息后的余额
        uint256 currentBalance = balanceOf(_user);
        // 利息
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // 铸造与利息等价的代币
        _mint(_user, balanceIncrease);
        // 将用户最后更新的时间戳更新为反映他们最近一次收到兴趣的时间。
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * 总余额（本金+利息）
     * @param _user 用户地址
     */
    function balanceOf(address _user) public view override(ERC20, IRebaseToken) returns (uint256) {
        //current principal balance of the user
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        // shares * current accumulated interest for that user since their interest was last minted to them.
        return (currentPrincipalBalance * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
     * 计算用户自上次更新以来累计的利息
     * @param _user 用户地址
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeDifference = block.timestamp - s_userLastUpdatedTimestamp[_user];
        // represents the linear growth over time = 1 + (interest rate * time)
        linearInterest = (s_userInterestRate[_user] * timeDifference) + PRECISION_FACTOR;
    }

    /**
     * 燃烧代币
     * @param account 账户地址
     * @param amount 燃烧代币数量
     */
    function burn(address account, uint256 amount) external override onlyRole(MINT_AND_BURN_ROLE) {
        if(amount == type(uint256).max) {
            amount = balanceOf(account);
        }
        // 更新用户的余额（本金+利息）
        _mintAccruedInterest(account);
        // 燃烧掉代币
        _burn(account, amount);
    }

    /**
     * @notice 转账
     * @param to 接收者地址
     * @param amount 转账数量
     */
    function transfer(address to, uint256 amount) public override returns(bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        if(amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        // 仅在用户尚未获得利率（或他们转移/燃烧了所有代币）时更新用户的利率，否则人们可以强迫他人获得较低的利率。
        if(balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[msg.sender];
        }
        // 转账后，利率遵循较低的账户的利率。因为有些会早早入场存入少量的钱享受较高的利率，然后后续通过另一个钱包转不断的向利率高的账户存钱获取更多的利息
        
        return super.transfer(to, amount);
    }

    /**
     * @notice 转账
     * @param _sender 发送者地址
     * @param _recipient 接收者地址
     * @param _amount 发送数量
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // accumulates the balance of the user so it is up to date with any interest accumulated.
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            // Update the users interest rate only if they have not yet got one (or they tranferred/burned all their tokens). Otherwise people could force others to have lower interest.
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * 本金余额
     * @param _user 用户地址
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    
}