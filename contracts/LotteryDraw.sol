// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/ILuckRaw.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract LotteryDraw is Ownable, ILuckRaw {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInterest {
        uint256 amount0;
        uint256 amount1;
    }
    mapping(address => UserInterest) private _userInterests;

    uint256 totalAmount0 = 0;
    uint256 totalAmount1 = 0;

    function Accumulate(
        address owner,
        uint256 amount0,
        uint256 amount1
    ) external override onlyOwner {
        UserInterest storage userInterest = _userInterests[owner];
        userInterest.amount0 += amount0;
        userInterest.amount1 += amount1;
        _userInterests[owner] = userInterest;
        totalAmount0 += amount0;
        totalAmount1 += amount1;
    }

    function claim() external override {
        UserInterest storage userInterest = _userInterests[msg.sender];

        settleReward();
        require(
            _totalReward0.add(_totalReward1) > 0,
            "this pool do not have any reward coin"
        );
        uint256 reward0 = 0;
        uint256 reward1 = 0;
        if (totalAmount0 > 0) {
            reward0 = userInterest.amount0.mul(_totalReward0).div(totalAmount0);
        }
        if (totalAmount1 > 0) {
            reward1 = userInterest.amount1.mul(_totalReward1).div(totalAmount1);
        }

        _totalReward0 -= reward0;
        _totalReward1 -= reward1;
        rewardUser(msg.sender, reward0.add(reward1));

        totalAmount0 -= userInterest.amount0;
        totalAmount1 -= userInterest.amount1;
        userInterest.amount0 = 0;
        userInterest.amount1 = 0;
    }

    function getUserInterest(address owner)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return (_userInterests[owner].amount0, _userInterests[owner].amount1);
    }

    function getTotalInterest()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return (totalAmount0, totalAmount1);
    }

    function getRewardPool()
        public
        view
        returns (uint256 totalReward0, uint256 totalReward1)
    {
        uint256 blockDiff = block.number.sub(_lastRewardBlock);
        if (blockDiff < _blockPerCycle) {
            return (_totalReward0, _totalReward1);
        }
        uint256 cycleNumber = blockDiff.div(_blockPerCycle);
        uint256 blanaceContract =
            IERC20(_rewardAddress).balanceOf(address(this));
        uint256 restReward =
            blanaceContract.sub(_totalReward0).sub(_totalReward1);
        uint256 avaibleCycle =
            restReward.div(_reward0PerCycle.add(_reward1PerCycle));
        cycleNumber = cycleNumber < avaibleCycle ? cycleNumber : avaibleCycle;
        return (
            _totalReward0.add(cycleNumber.mul(_reward0PerCycle)),
            _totalReward1.add(cycleNumber.mul(_reward1PerCycle))
        );
    }

    function getRewardParam()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address
        )
    {
        return (
            _blockPerCycle,
            _reward0PerCycle,
            _reward1PerCycle,
            _lastRewardBlock,
            _rewardAddress
        );
    }

    //----------------------------------------------------------------
    address internal _executor;
    address internal _rewardAddress;
    uint256 internal _totalReward0;
    uint256 internal _totalReward1;
    uint256 internal _blockPerCycle;
    uint256 internal _reward0PerCycle;
    uint256 internal _reward1PerCycle;
    uint256 internal _lastRewardBlock;

    constructor(address rewardAddress) {
        _executor = msg.sender;
        _rewardAddress = rewardAddress;
        _lastRewardBlock = block.number;
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

    function transferexecutor(address newExecutor) public virtual onlyExecutor {
        require(
            newExecutor != address(0),
            "executor: new executor is the zero address"
        );
        _executor = newExecutor;
    }

    function setRewardParam(
        uint256 blockPerCycle,
        uint256 reward0PerCycle,
        uint256 reward1PerCycle
    ) public onlyExecutor {
        require(blockPerCycle > 0, "invalid blockPerCycle");
        require(
            reward0PerCycle + reward1PerCycle > 0,
            "invalid reward0PerCycle and reward1PerCycle"
        );
        _blockPerCycle = blockPerCycle;
        _reward0PerCycle = reward0PerCycle;
        _reward1PerCycle = reward1PerCycle;
    }

    function settleReward() internal {
        require(_blockPerCycle > 0, "blockPerCycle has not been set");
        uint256 blockDiff = block.number.sub(_lastRewardBlock);
        if (blockDiff < _blockPerCycle) {
            return;
        }
        uint256 cycleNumber = blockDiff.div(_blockPerCycle);
        uint256 blanaceContract =
            IERC20(_rewardAddress).balanceOf(address(this));
        uint256 restReward =
            blanaceContract.sub(_totalReward0).sub(_totalReward1);
        uint256 avaibleCycle =
            restReward.div(_reward0PerCycle.add(_reward1PerCycle));
        cycleNumber = cycleNumber < avaibleCycle ? cycleNumber : avaibleCycle;
        _totalReward0 = _totalReward0.add(cycleNumber.mul(_reward0PerCycle));
        _totalReward1 = _totalReward1.add(cycleNumber.mul(_reward1PerCycle));
        _lastRewardBlock = block.number;
    }

    function rewardUser(address user, uint256 reward) internal {
        IERC20(_rewardAddress).safeTransfer(user, reward);
    }
}
