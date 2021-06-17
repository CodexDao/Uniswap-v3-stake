import { Fixture } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { v3RouterFixture } from './externalFixtures'
import { constants } from 'ethers'
import {
  IWETH9,
  MockTimeNonfungiblePositionManager,
  MockTimeSwapRouter,
  TestERC20,
  IUniswapV3Factory,
  LuckManager,
  PairCreate,
} from '../../typechain'

const completeFixture: Fixture<{
  weth9: IWETH9
  factory: IUniswapV3Factory
  router: MockTimeSwapRouter
  nft: MockTimeNonfungiblePositionManager
  tokens: [TestERC20, TestERC20, TestERC20]
  luckManager: LuckManager
  pairCreate: PairCreate
}> = async (wallets, provider) => {
  const { weth9, factory, router } = await v3RouterFixture(wallets, provider)

  const tokenFactory = await ethers.getContractFactory('TestERC20')
  const tokens = (await Promise.all([
    tokenFactory.deploy(constants.MaxUint256.div(2)), // do not use maxu256 to avoid overflowing
    tokenFactory.deploy(constants.MaxUint256.div(2)),
    tokenFactory.deploy(constants.MaxUint256.div(2)),
  ])) as [TestERC20, TestERC20, TestERC20]

  const nftDescriptorLibraryFactory = await ethers.getContractFactory('NFTDescriptor')
  const nftDescriptorLibrary = await nftDescriptorLibraryFactory.deploy()
  const positionDescriptorFactory = await ethers.getContractFactory('NonfungibleTokenPositionDescriptor', {
    libraries: {
      NFTDescriptor: nftDescriptorLibrary.address,
    },
  })
  const positionDescriptor = await positionDescriptorFactory.deploy(tokens[0].address)

  const luckManagerFactory = await ethers.getContractFactory('LuckManager')
  const luckManager = (await luckManagerFactory.deploy()) as LuckManager;

  const pairCreateFactory = await ethers.getContractFactory('PairCreate')
  const pairCreate = (await pairCreateFactory.deploy(factory.address,
    weth9.address)) as PairCreate;

  const positionManagerFactory = await ethers.getContractFactory('MockTimeNonfungiblePositionManager')
  const nft = (await positionManagerFactory.deploy(
    factory.address,
    weth9.address,
    positionDescriptor.address,
    luckManager.address
  )) as MockTimeNonfungiblePositionManager

  await luckManager.setPositionManagerAddress(nft.address);

  tokens.sort((a, b) => (a.address.toLowerCase() < b.address.toLowerCase() ? -1 : 1))

  return {
    weth9,
    factory,
    router,
    nft,
    tokens,
    luckManager,
    pairCreate
  }
}

export default completeFixture
