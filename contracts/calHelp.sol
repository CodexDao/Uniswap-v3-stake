// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import "./libraries/PositionKey.sol";
import "./libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./interfaces/INonfungiblePositionManager.sol";

contract calHelp {
    function getSqrtRatioAtTick(int24 tick) public pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96)
        public
        pure
        returns (int24)
    {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function getPoolAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) public pure returns (address) {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee});
        address pairAddress = PoolAddress.computeAddress(factory, poolKey);
        return pairAddress;
    }

    function getUserTokenAmount(address positionManager, uint256 tokenId)
        public
        view
        returns (int256 amount0, int256 amount1)
    {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        IUniswapV3Pool pool =
            IUniswapV3Pool(
                PoolAddress.computeAddress(
                    INonfungiblePositionManager(positionManager).factory(),
                    PoolAddress.PoolKey({
                        token0: token0,
                        token1: token1,
                        fee: fee
                    })
                )
            );

        (, int24 currentTick, , , , , ) = pool.slot0();

        if (currentTick < tickLower) {
            amount0 = SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                (int128)(liquidity)
            );
        } else if (currentTick < tickUpper) {
            amount0 = SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtRatioAtTick(currentTick),
                TickMath.getSqrtRatioAtTick(tickUpper),
                (int128)(liquidity)
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(currentTick),
                (int128)(liquidity)
            );
        } else {
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                (int128)(liquidity)
            );
        }
        return (amount0, amount1);
    }

    function getPositionGrowthInside(address positionManager, uint256 tokenId)
        public
        view
        returns (uint256, uint256)
    {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        IUniswapV3Pool pool =
            IUniswapV3Pool(
                PoolAddress.computeAddress(
                    INonfungiblePositionManager(positionManager).factory(),
                    PoolAddress.PoolKey({
                        token0: token0,
                        token1: token1,
                        fee: fee
                    })
                )
            );

        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) =
            pool.positions(
                PositionKey.compute(positionManager, tickLower, tickUpper)
            );

        return (feeGrowthInside0LastX128, feeGrowthInside1LastX128);
    }

    function getUserInterest(address positionManager, uint256 tokenId)
        public
        view
        returns (uint256, uint256)
    {
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidity,
            uint256 positionFeeGrowthInside0LastX128,
            uint256 positionFeeGrowthInside1LastX128,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            getPositionGrowthInside(positionManager, tokenId);
        return (
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - positionFeeGrowthInside0LastX128,
                    liquidity,
                    FixedPoint128.Q128
                )
            ),
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - positionFeeGrowthInside1LastX128,
                    liquidity,
                    FixedPoint128.Q128
                )
            )
        );
    }
}
