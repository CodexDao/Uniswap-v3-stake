// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

//给 NonfungiblePositionManager的接口 需要权限校验 Owner  如何把Owner属性加上？
interface ILuckRaw {
    //累积
    function Accumulate(
        address owner,
        uint256 amount0,
        uint256 amount1
    ) external;

    //发放
    function claim() external;
}
