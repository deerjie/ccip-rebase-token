// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IRebaseToken
 * @author cedar
 * @notice 
 */
interface IRebaseToken {
    /**
     * 铸造
     * @param to to
     * @param amount amount
     */
    function mint(address to, uint256 amount, uint256 _userInterestRate) external;
    /**
     * 销毁
     * @param from from
     * @param amount amount
     */
    function burn(address from, uint256 amount) external;
    /**
     * 余额
     * @param account 账户address
     */
    function balanceOf(address account) external view returns (uint256);
    function getUserInterestRate(address _account) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
    function grantMintAndBurnRole(address _account) external;
}