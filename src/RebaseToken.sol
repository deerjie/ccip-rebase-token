// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author cedar
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 */
contract RebaseToken is ERC20{
    // State variables
    uint256 public s_interestRate; // 利率
    
   // Error
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 s_interestRate, uint256 _newInterestRate);
    
    

    
    constructor() ERC20("REBASE_TOKEN","RBT") {}

    /**
     * 初始化利率
     * @param _newInterestRate 利率
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // 利率只能降低
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
    }

    
}