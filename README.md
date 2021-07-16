# Uniswap-v3-stake
Qilin liquidity mining contract for Uniswap V3

## Features

This contract realizes that while adding liquidity in Uniswap-v3, mining is carried out in this contract. The value of mining is the amount of handling fees obtained in uniswap-core.

The contract records the user's mining information by recording the amount of fees the user obtains on uniswap-v3, and distributes rewards to the user based on the mining information.

## contracts

+ NonfungiblePositionManager.sol
+ LuckManager.sol
+ LotteryDraw.sol

### NonfungiblePositionManager

The NonfungiblePositionManager contract implements the function of managing user positions. Users can add liquidity to Uniswap-v3 through this contract, remove liquidity, and receive tokens. When the user operates in the contract, the contract will automatically record the fee rewards the user obtains in Uniswap-v3, and synchronize the fee information to the LuckManager contract, which is synchronized to the LotteryDraw contract.

### LuckManager

The LuckManager contract implements the routing function for mining information, and synchronizes the fee information obtained by the user in Uniswap-v3 from the NonfungiblePositionManager contract to the corresponding LotteryDraw contract in real time

### LotteryDraw

The LotteryDraw contract realizes the record of the handling fee obtained by the user in Uniswap-v3 and rewards for changing the record. Rewards can be sent to the contract address by the team of creators of the LotteryDraw contract, and the reward cycle of the contract and the number of rewards in each cycle can be set. Users can receive corresponding rewards in the LotteryDraw contract.

**A transaction pair can only correspond to one LotteryDraw contract. The information of the contract and the transaction pair needs to be registered in LuckManager to normally record the user's handling fee information and issue mining rewards to the user**