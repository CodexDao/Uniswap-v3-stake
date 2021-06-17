// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/ILuckRawAccumulate.sol";
import "./interfaces/ILuckRaw.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/PoolAddress.sol";
import "./LotteryDraw.sol";

contract LuckManager is ILuckRawAccumulate, Ownable {
    mapping(address => address) private _seat;
    address private _nonFungiblePositionManager;

    //event
    event RegisterPair(address pairAddress, address luckyAddress);
    event UnregisterPair(address pairAddress);

    function setPositionManagerAddress(address nonFungiblePositionManager)
        public
        onlyOwner
    {
        _nonFungiblePositionManager = nonFungiblePositionManager;
        transferOwnership(nonFungiblePositionManager);
    }

    function register(address _pairAddress, address _luckRawAddress)
        public
        onlyExecutor
    {
        require(
            _nonFungiblePositionManager != address(0),
            "nonFungiblePositionManager has not been setted"
        );
        require(
            _seat[_pairAddress] == address(0),
            "the seat has been rigisterd"
        );
        _seat[_pairAddress] = _luckRawAddress;
        emit RegisterPair(_pairAddress, _luckRawAddress);
    }

    function removeLuckRaw(address _pairAddress) public onlyExecutor {
        require(
            _seat[_pairAddress] != address(0),
            "the seat has not been rigisterd"
        );
        _seat[_pairAddress] = address(0);
        emit UnregisterPair(_pairAddress);
    }

    function getLuckRawAddress(address _pairAddress)
        public
        view
        returns (address)
    {
        return _seat[_pairAddress];
    }

    function Accumulate(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) external override onlyOwner {
        (, , address token0, address token1, uint24 fee, , , , , , , ) =
            INonfungiblePositionManager(_nonFungiblePositionManager).positions(
                tokenId
            );
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee});
        address pairAddress =
            PoolAddress.computeAddress(
                INonfungiblePositionManager(_nonFungiblePositionManager)
                    .factory(),
                poolKey
            );
        if (_seat[pairAddress] == address(0)) return;
        ILuckRaw(_seat[pairAddress]).Accumulate(
            IERC721(_nonFungiblePositionManager).ownerOf(tokenId),
            amount0,
            amount1
        );
    }

    address internal _executor;

    constructor() {
        _executor = msg.sender;
    }

    function executor() public view virtual returns (address) {
        return _executor;
    }

    modifier onlyExecutor() {
        require(
            executor() == msg.sender,
            "executor: caller is not the executor"
        );
        _;
    }

    function createLotteryDraw(
        address pairAddress,
        address rewardCoin,
        uint256 blockPerCycle,
        uint256 reward0PerCycle,
        uint256 reward1PerCycle,
        uint256 initRewardAmount
    ) public returns (address) {
        require(
            _seat[pairAddress] == address(0),
            "the seat has been rigisterd"
        );
        require(
            _nonFungiblePositionManager != address(0),
            "nonFungiblePositionManager has not been setted"
        );

        require(initRewardAmount > 0, "invalid initRewardAmount");

        LotteryDraw _newLotteryDraw = new LotteryDraw(rewardCoin);
        _newLotteryDraw.setRewardParam(
            blockPerCycle,
            reward0PerCycle,
            reward1PerCycle
        );
        _newLotteryDraw.transferexecutor(msg.sender);
        IERC20(rewardCoin).transferFrom(
            msg.sender,
            address(_newLotteryDraw),
            initRewardAmount
        );
        _seat[pairAddress] = address(_newLotteryDraw);
        emit RegisterPair(pairAddress, address(_newLotteryDraw));
        return address(_newLotteryDraw);
    }
}
