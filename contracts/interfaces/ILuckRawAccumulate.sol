// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

//给 NonfungiblePositionManager的接口 需要权限校验 Owner  如何把Owner属性加上？
interface ILuckRawAccumulate {
    function Accumulate(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) external;
}
