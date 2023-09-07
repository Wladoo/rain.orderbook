// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ArbTest, ArbTestConstructorConfig} from "test/util/abstract/ArbTest.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";

import "test/util/lib/LibTestConstants.sol";
import "test/util/lib/LibGenericPoolOrderBookV3ArbOrderTakerConstants.sol";

import "src/concrete/GenericPoolOrderBookV3ArbOrderTaker.sol";
import "src/interface/unstable/IOrderBookV3.sol";

import "test/util/concrete/FlashLendingMockOrderBook.sol";

contract GenericPoolOrderBookV3ArbOrderTakerTest is ArbTest {
    function buildArbTestConstructorConfig() internal returns (ArbTestConstructorConfig memory) {
        (address deployer, DeployerDiscoverableMetaV2ConstructionConfig memory config) =
            buildConstructorConfig(GENERIC_POOL_ORDER_BOOK_V3_ARB_ORDER_TAKER_META_PATH);
        return ArbTestConstructorConfig(deployer, address(new GenericPoolOrderBookV3ArbOrderTaker(config)));
    }

    constructor() ArbTest(buildArbTestConstructorConfig()) {}

    function testTakeOrdersSender(Order memory order, uint256 inputIOIndex, uint256 outputIOIndex) public {
        vm.assume(order.validInputs.length > 0);
        inputIOIndex = bound(inputIOIndex, 0, order.validInputs.length - 1);
        vm.assume(order.validOutputs.length > 0);
        outputIOIndex = bound(outputIOIndex, 0, order.validOutputs.length - 1);

        FlashLendingMockOrderBook ob = new FlashLendingMockOrderBook();

        GenericPoolOrderBookV3ArbOrderTaker arb = GenericPoolOrderBookV3ArbOrderTaker(Clones.clone(iImplementation));
        arb.initialize(
            abi.encode(
                OrderBookV3ArbOrderTakerConfigV1(
                    address(ob), EvaluableConfigV2(IExpressionDeployerV2(address(0)), "", new uint256[](0)), ""
                )
            )
        );

        order.validInputs[inputIOIndex].token = address(iTakerOutput);
        order.validOutputs[outputIOIndex].token = address(iTakerInput);

        TakeOrderConfig[] memory orders = new TakeOrderConfig[](1);
        orders[0] = TakeOrderConfig(order, inputIOIndex, outputIOIndex, new SignedContextV1[](0));

        arb.arb(
            TakeOrdersConfigV2(0, type(uint256).max, type(uint256).max, orders, abi.encode(iRefundoor, iRefundoor, "")),
            0
        );
    }

    function testMinimumOutput(
        Order memory order,
        uint256 inputIOIndex,
        uint256 outputIOIndex,
        uint256 minimumOutput,
        uint256 mintAmount
    ) public {
        vm.assume(order.validInputs.length > 0);
        inputIOIndex = bound(inputIOIndex, 0, order.validInputs.length - 1);
        vm.assume(order.validOutputs.length > 0);
        outputIOIndex = bound(outputIOIndex, 0, order.validOutputs.length - 1);

        vm.assume(minimumOutput > mintAmount);
        FlashLendingMockOrderBook ob = new FlashLendingMockOrderBook();

        GenericPoolOrderBookV3ArbOrderTaker arb = GenericPoolOrderBookV3ArbOrderTaker(Clones.clone(iImplementation));
        arb.initialize(
            abi.encode(
                OrderBookV3ArbOrderTakerConfigV1(
                    address(ob), EvaluableConfigV2(IExpressionDeployerV2(address(0)), "", new uint256[](0)), ""
                )
            )
        );

        iTakerOutput.mint(address(arb), mintAmount);

        order.validInputs[inputIOIndex].token = address(iTakerOutput);
        order.validOutputs[outputIOIndex].token = address(iTakerInput);

        TakeOrderConfig[] memory orders = new TakeOrderConfig[](1);
        orders[0] = TakeOrderConfig(order, inputIOIndex, outputIOIndex, new SignedContextV1[](0));

        vm.expectRevert(abi.encodeWithSelector(MinimumOutput.selector, minimumOutput, mintAmount));
        arb.arb(
            TakeOrdersConfigV2(0, type(uint256).max, type(uint256).max, orders, abi.encode(iRefundoor, iRefundoor, "")),
            minimumOutput
        );
    }
}
