import {
    TestERC20,
    LotteryDraw,
} from '../typechain'
import { waffle, ethers } from 'hardhat'
import { constants } from 'ethers'
import { expect } from './shared/expect'
import { createTimeMachine } from './shared/time'



describe('LotteryDraw', () => {
    const wallets = waffle.provider.getWallets()
    const [wallet, other] = wallets
    const Time = createTimeMachine(waffle.provider)


    let rewardToken: TestERC20
    let lotteryInstance: LotteryDraw

    beforeEach('create LotteryInstance loader', async () => {
        const tokenFactory = await ethers.getContractFactory('TestERC20')
        rewardToken = (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20;// do not use maxu256 to avoid overflowing
        const LotteryDrawFactory = await ethers.getContractFactory('LotteryDraw');
        lotteryInstance = (await LotteryDrawFactory.deploy(rewardToken.address,
        )) as LotteryDraw;
    })

    describe('#lotteryDraw function', async () => {
        it('setRewardParam with different params', async () => {
            await lotteryInstance.setRewardParam(1, 50, 100);

            await expect(lotteryInstance.setRewardParam(0, 50, 100)).to.be.revertedWith("invalid blockPerCycle");
            await expect(lotteryInstance.setRewardParam(1, 0, 0)).to.be.revertedWith("invalid reward0PerCycle and reward1PerCycle");
        });

        it('Accumulate and claim', async () => {
            await lotteryInstance.setRewardParam(1, 50, 100);
            await rewardToken.transfer(lotteryInstance.address, 100000000);
            await lotteryInstance.Accumulate(other.address, 50, 100);
            await Time.advanceBlockWithNumber(100);
            await lotteryInstance.connect(other).claim();
        });

    });

});