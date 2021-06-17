// import { BigNumberish, constants } from 'ethers'
import { BigNumber, constants, Contract, ContractTransaction } from 'ethers'
import { encodePath } from './shared/path'

import { waffle, ethers } from 'hardhat'
import { expect } from './shared/expect'
import { encodePriceSqrt } from './shared/encodePriceSqrt'
import { getMaxTick, getMinTick } from './shared/ticks'
import { Fixture } from 'ethereum-waffle'
import {
    TestPositionNFTOwner,
    MockTimeNonfungiblePositionManager,
    TestERC20,
    IWETH9,
    IUniswapV3Factory,
    SwapRouter,
    LuckManager,
    PairCreate,
    LotteryDraw,
} from '../typechain'
import completeFixture from './shared/completeFixture'
import { computePoolAddress } from './shared/computePoolAddress'
import { FeeAmount, MaxUint128, TICK_SPACINGS } from './shared/constants'
import { sortedTokens } from './shared/tokenSort'
import { expandTo18Decimals } from './shared/expandTo18Decimals'
import { abi as IUniswapV3PoolABI } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json'

describe('luckManager', () => {
    const wallets = waffle.provider.getWallets()
    const [wallet, other] = wallets

    const nftFixture: Fixture<{
        nft: MockTimeNonfungiblePositionManager
        factory: IUniswapV3Factory
        tokens: [TestERC20, TestERC20, TestERC20]
        weth9: IWETH9
        router: SwapRouter,
        luckManager: LuckManager,
        pairCreate: PairCreate
    }> = async (wallets, provider) => {
        const { weth9, factory, tokens, nft, router, luckManager, pairCreate } = await completeFixture(wallets, provider)

        // approve & fund wallets
        for (const token of tokens) {
            await token.approve(nft.address, constants.MaxUint256)
            await token.connect(other).approve(nft.address, constants.MaxUint256)
            await token.transfer(other.address, expandTo18Decimals(1_000_000))
        }

        return {
            nft,
            factory,
            tokens,
            weth9,
            router,
            luckManager,
            pairCreate,
        }
    }

    let factory: IUniswapV3Factory
    let nft: MockTimeNonfungiblePositionManager
    let tokens: [TestERC20, TestERC20, TestERC20]
    let weth9: IWETH9
    let router: SwapRouter
    let pairCreate: PairCreate
    let luckManager: LuckManager

    let loadFixture: ReturnType<typeof waffle.createFixtureLoader>

    before('create fixture loader', async () => {
        loadFixture = waffle.createFixtureLoader(wallets)
    })

    beforeEach('load fixture', async () => {
        ; ({ nft, factory, tokens, weth9, router, luckManager, pairCreate } = await loadFixture(nftFixture))
    })

    describe('#createLotteryDraw', () => {
        it('creates a lotteryDraw for new pair', async () => {
            //approve
            await expect(luckManager.createLotteryDraw(
                tokens[1].address, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )).to.be.reverted

            await tokens[0].approve(luckManager.address, 10000000000)

            await luckManager.createLotteryDraw(
                tokens[1].address, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )

            await expect(luckManager.createLotteryDraw(
                tokens[1].address, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )).to.be.revertedWith('the seat has been rigisterd');

            await expect(luckManager.register(tokens[1].address, tokens[0].address)).to.be.revertedWith('the seat has been rigisterd');
            await luckManager.removeLuckRaw(tokens[1].address);
            await tokens[0].approve(luckManager.address, 10000000000)

            await luckManager.createLotteryDraw(
                tokens[1].address, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )

            await luckManager.removeLuckRaw(tokens[1].address);
            await luckManager.register(tokens[1].address, tokens[0].address)

            await expect(luckManager.createLotteryDraw(
                tokens[1].address, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )).to.be.reverted
        });

        async function exactInput(
            tokens: string[],
            amountIn: number = 3,
            amountOutMinimum: number = 1
        ): Promise<ContractTransaction> {
            const inputIsWETH = weth9.address === tokens[0]
            const outputIsWETH9 = tokens[tokens.length - 1] === weth9.address

            const value = inputIsWETH ? amountIn : 0

            const params = {
                path: encodePath(tokens, new Array(tokens.length - 1).fill(FeeAmount.MEDIUM)),
                recipient: outputIsWETH9 ? constants.AddressZero : other.address,
                deadline: 1,
                amountIn,
                amountOutMinimum,
            }

            const data = [router.interface.encodeFunctionData('exactInput', [params])]
            if (outputIsWETH9)
                data.push(router.interface.encodeFunctionData('unwrapWETH9', [amountOutMinimum, other.address]))

            // optimized for the gas test
            return data.length === 1
                ? router.connect(other).exactInput(params, { value })
                : router.connect(other).multicall(data, { value })
        }

        it('lotteryDraw Accumulate with position change', async () => {
            //创建pair
            const expectedAddress = computePoolAddress(
                factory.address,
                [tokens[0].address, tokens[1].address],
                FeeAmount.MEDIUM
            )

            await pairCreate.createAndInitializePoolIfNecessary(
                tokens[0].address,
                tokens[1].address,
                FeeAmount.MEDIUM,
                encodePriceSqrt(1, 1)
            )
            await tokens[0].approve(nft.address, 10000000000)
            await tokens[1].approve(nft.address, 10000000000)

            await nft.mint({
                token0: tokens[0].address,
                token1: tokens[1].address,
                tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
                tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
                fee: FeeAmount.MEDIUM,
                recipient: other.address,
                amount0Desired: 15,
                amount1Desired: 15,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 100000000000000,
            })

            await tokens[0].approve(luckManager.address, 10000000000)

            await luckManager.createLotteryDraw(
                expectedAddress, tokens[0].address,
                1,
                50,
                100,
                10000000000
            )

            const tokenId = 1
            //至少是通过的
            await nft.increaseLiquidity({
                tokenId: tokenId,
                amount0Desired: 100000,
                amount1Desired: 100000,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 100000000000000,
            })


            await tokens[0].connect(other).approve(router.address, 10000000000)
            await tokens[1].connect(other).approve(router.address, 10000000000)

            await exactInput(
                tokens
                    .slice(0, 2)
                    .reverse()
                    .map((token) => token.address), 50000, 10
            )

            await nft.connect(other).decreaseLiquidity({ tokenId, liquidity: 50, amount0Min: 0, amount1Min: 0, deadline: 100000000000000 })
            var lotteryDrawAddress = await luckManager.getLuckRawAddress(expectedAddress);
            const LotteryDrawInstance = await ethers.getContractAt('LotteryDraw', lotteryDrawAddress);
            var totalInterest = await LotteryDrawInstance.getTotalInterest();
            expect(totalInterest[0].eq(0)).to.be.eq(true);
            expect(totalInterest[1].eq(0)).to.be.eq(false);

            await luckManager.removeLuckRaw(expectedAddress);

            await tokens[0].connect(other).approve(router.address, 10000000000)
            await tokens[1].connect(other).approve(router.address, 10000000000)

            await exactInput(
                tokens
                    .slice(0, 2)
                    .reverse()
                    .map((token) => token.address), 50000, 10
            )
            await nft.connect(other).collect({
                tokenId,
                recipient: wallet.address,
                amount0Max: MaxUint128,
                amount1Max: MaxUint128,
            })
        })
    });
});