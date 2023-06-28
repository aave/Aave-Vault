pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import {IERC20} from '../../lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IAToken} from "../../lib/aave-v3-core/contracts/interfaces/IAToken.sol";

contract SymbolicLendingPoolL1 {
    // underlying asset address -> AToken address of that token.
    mapping(address => address) public underlyingAssetToAToken_L1;
    // underlying asset -> pool liquidity index of that asset
    // This index is used to convert the underlying token to its matching
    // AToken inside the pool, and vice versa.
    mapping(address => uint256) public liquidityIndex;

    /**
     * @dev Deposits underlying token in the Atoken's contract on behalf of the user,
            and mints Atoken on behalf of the user in return.
     * @param asset The underlying sent by the user and to which Atoken shall be minted
     * @param amount The amount of underlying token sent by the user
     * @param onBehalfOf The recipient of the minted Atokens
     * @param referralCode A unique code (unused)
     **/
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        IERC20(asset).transferFrom(
            msg.sender,
            underlyingAssetToAToken_L1[asset],
            amount
        );
        IAToken(underlyingAssetToAToken_L1[asset]).mint(
            msg.sender,  //TODO: review added argument
            onBehalfOf,
            amount,
            liquidityIndex[asset]
        );
    }

    /**
     * @dev Burns Atokens in exchange for underlying asset
     * @param asset The underlying asset to which the Atoken is connected
     * @param amount The amount of underlying tokens to be burned
     * @param to The recipient of the burned Atokens
     * @return The `amount` of tokens withdrawn
     **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        IAToken(underlyingAssetToAToken_L1[asset]).burn(
            msg.sender,
            to,
            amount,
            liquidityIndex[asset]
        );
        return amount;
    }

    /**
     * @dev A simplification returning a constant
     * @param asset The underlying asset to which the Atoken is connected
     * @return liquidityIndex the `liquidityIndex` of the asset
     **/
    function getReserveNormalizedIncome(address asset)
        external
        view
        virtual
        returns (uint256)
    {
        return liquidityIndex[asset];
    }


    // Original code from AAVE LendingPool:
    // The version we use above assumes timestamp == uint40(block.timestamp) 
    // or alternatively, a very small value for LiquidityRate.
    /*
    * @dev Returns the ongoing normalized income for the reserve
    * A value of 1e27 means there is no income. As time passes, the income is accrued
    * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
    * @param reserve The reserve object
    * @return the normalized income. expressed in ray
    */
    /* 
    function getNormalizedIncome(DataTypes.ReserveData storage reserve)
    internal
    view
    returns (uint256)
    {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == uint40(block.timestamp)) {
        //if the index was updated in the same block, no need to perform any calculation
        return reserve.liquidityIndex;
    }

    uint256 cumulated =
        MathUtils.calculateLinearInterest(reserve.currentLiquidityRate, timestamp).rayMul(
        reserve.liquidityIndex
        );

    return cumulated;
    }
    */

    // Returns the Atoken address of an underlying asset.
    // function underlyingtoAToken(address asset) external view
    // returns(address){
    //     return underlyingAssetToAToken_L1[asset];
    // }

    // // Returns the pool liquidity index of an underlying asset.
    // function liquidityIndexByAsset(address asset) external view
    // returns(uint256){
    //     return liquidityIndex[asset];
    // }
}
