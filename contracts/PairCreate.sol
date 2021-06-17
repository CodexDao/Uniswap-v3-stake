// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
pragma abicoder v2;
import "./base/PoolInitializer.sol";

contract PairCreate is PoolInitializer {
    constructor(address _factory, address _WETH9)
        PeripheryImmutableState(_factory, _WETH9)
    {}
}
