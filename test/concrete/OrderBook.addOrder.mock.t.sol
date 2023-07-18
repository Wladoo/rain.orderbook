// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "rain.metadata/LibMeta.sol";

import "test/util/abstract/OrderBookExternalMockTest.sol";
import "test/util/lib/LibTestAddOrder.sol";

/// @title OrderBookAddOrderMockTest
/// @notice Tests the addOrder function of the OrderBook contract.
contract OrderBookAddOrderMockTest is OrderBookExternalMockTest, IMetaV1 {
    /// Boilerplate to add an order with a mocked deployer and checks events and
    /// storage accesses.
    function addOrderWithChecks(address owner, OrderConfig memory config, address expression)
        internal
        returns (Order memory, bytes32)
    {
        config.evaluableConfig.deployer = iDeployer;
        (Order memory order, bytes32 orderHash) =
            LibTestAddOrder.expectedOrder(owner, config, iInterpreter, iStore, expression);
        assertTrue(!iOrderbook.orderExists(orderHash));
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV1.deployExpression.selector),
            abi.encode(iInterpreter, iStore, expression)
        );
        vm.expectEmit(false, false, false, true);
        emit AddOrder(owner, iDeployer, order, orderHash);
        if (config.meta.length > 0) {
            vm.expectEmit(false, false, true, false);
            // The subject of the meta is the order hash.
            emit MetaV1(owner, uint256(orderHash), config.meta);
        }
        vm.record();
        vm.recordLogs();
        vm.prank(owner);
        iOrderbook.addOrder(config);
        // MetaV1 is NOT emitted if the meta is empty.
        assertEq(vm.getRecordedLogs().length, config.meta.length > 0 ? 2 : 1);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(iOrderbook));
        // 3x for reentrancy guard, 1x for dead order check, 1x for live write.
        assertEq(reads.length, 5);
        // 2x for reentrancy guard, 1x for live write.
        assertEq(writes.length, 3);
        assertTrue(iOrderbook.orderExists(orderHash));

        // Adding the same order again MUST revert. This MAY be impossible to
        // encounter for a real expression deployer, as the deployer MAY NOT
        // return the same address twice, but it is possible to mock.
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OrderExists.selector, owner, orderHash));
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV1.deployExpression.selector),
            abi.encode(iInterpreter, iStore, expression)
        );
        iOrderbook.addOrder(config);
        return (order, orderHash);
    }

    /// Adding an order without calculations MUST revert.
    function testAddOrderWithoutCalculationsReverts(address owner, OrderConfig memory config) public {
        vm.prank(owner);
        config.evaluableConfig.sources = new bytes[](0);
        vm.expectRevert(abi.encodeWithSelector(OrderNoSources.selector, owner));
        iOrderbook.addOrder(config);
        (Order memory order, bytes32 orderHash) =
            LibTestAddOrder.expectedOrder(owner, config, iInterpreter, iStore, address(0));
        (order);
        assertTrue(!iOrderbook.orderExists(orderHash));
    }

    /// Adding an order without inputs MUST revert.
    function testAddOrderWithoutInputsReverts(address owner, OrderConfig memory config) public {
        vm.prank(owner);
        vm.assume(config.evaluableConfig.sources.length > 1);
        config.validInputs = new IO[](0);
        vm.expectRevert(abi.encodeWithSelector(OrderNoInputs.selector, owner));
        iOrderbook.addOrder(config);
        (Order memory order, bytes32 orderHash) =
            LibTestAddOrder.expectedOrder(owner, config, iInterpreter, iStore, address(0));
        (order);
        assertTrue(!iOrderbook.orderExists(orderHash));
    }

    /// Adding an order without outputs MUST revert.
    function testAddOrderWithoutOutputsReverts(address owner, OrderConfig memory config) public {
        vm.prank(owner);
        vm.assume(config.evaluableConfig.sources.length > 1);
        vm.assume(config.validInputs.length > 0);
        config.validOutputs = new IO[](0);
        vm.expectRevert(abi.encodeWithSelector(OrderNoOutputs.selector, owner));
        iOrderbook.addOrder(config);
        (Order memory order, bytes32 orderHash) =
            LibTestAddOrder.expectedOrder(owner, config, iInterpreter, iStore, address(0));
        (order);
        assertTrue(!iOrderbook.orderExists(orderHash));
    }

    /// Adding an order with calculations, inputs and outputs will succeed if
    /// the expression is valid according to the deployer. The resulting order
    /// MUST be emitted. This test assumes empty meta.
    function testAddOrderWithCalculationsInputsAndOutputsSucceeds(
        address owner,
        OrderConfig memory config,
        address expression
    ) public {
        vm.assume(config.evaluableConfig.sources.length >= 2);
        vm.assume(config.validInputs.length > 0);
        vm.assume(config.validOutputs.length > 0);
        config.meta = new bytes(0);
        (Order memory order, bytes32 orderhash) = addOrderWithChecks(owner, config, expression);
        (order);
        (orderhash);
    }

    /// Adding a valid order with a non-empty meta MUST revert if the meta is
    /// not self describing as a rain meta document.
    function testAddOrderWithNonEmptyMetaReverts(address owner, OrderConfig memory config, address expression) public {
        vm.prank(owner);
        vm.assume(config.evaluableConfig.sources.length >= 2);
        vm.assume(config.validInputs.length > 0);
        vm.assume(config.validOutputs.length > 0);
        vm.assume(!LibMeta.isRainMetaV1(config.meta));
        vm.assume(config.meta.length > 0);

        config.evaluableConfig.deployer = iDeployer;
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV1.deployExpression.selector),
            abi.encode(iInterpreter, iStore, expression)
        );
        vm.expectRevert(abi.encodeWithSelector(NotRainMetaV1.selector, config.meta));
        iOrderbook.addOrder(config);

        (Order memory order, bytes32 orderHash) =
            LibTestAddOrder.expectedOrder(owner, config, iInterpreter, iStore, expression);
        (order);
        assertTrue(!iOrderbook.orderExists(orderHash));
    }

    /// Adding a valid order with a non-empty meta MUST emit MetaV1 if the meta
    /// is self describing as a rain meta document.
    function testAddOrderWithNonEmptyMetaEmitsMetaV1(address owner, OrderConfig memory config, address expression)
        public
    {
        vm.assume(config.evaluableConfig.sources.length >= 2);
        vm.assume(config.validInputs.length > 0);
        vm.assume(config.validOutputs.length > 0);
        vm.assume(config.meta.length > 0);

        // This is a bit of a hack, but it's the easiest way to get a valid
        // meta document.
        config.meta = abi.encodePacked(META_MAGIC_NUMBER_V1, config.meta);

        (Order memory order, bytes32 orderHash) = addOrderWithChecks(owner, config, expression);
        (order);
        (orderHash);
    }

    /// Alice and Bob can add orders with the same config. The resulting orders
    /// MUST be different.
    function testAddOrderTwoAccountsWithSameConfig(
        address alice,
        address bob,
        OrderConfig memory config,
        address expression
    ) public {
        vm.assume(alice != bob);
        vm.assume(LibTestAddOrder.conformConfig(config, iDeployer));
        (Order memory aliceOrder, bytes32 aliceOrderHash) = addOrderWithChecks(alice, config, expression);
        (Order memory bobOrder, bytes32 bobOrderHash) = addOrderWithChecks(bob, config, expression);
        (aliceOrder);
        (bobOrder);
        assertTrue(aliceOrderHash != bobOrderHash);
    }

    /// Alice and Bob can add orders with different configs. The resulting orders
    /// MUST be different.
    function testAddOrderTwoAccountsWithDifferentConfig(
        address alice,
        address bob,
        OrderConfig memory aliceConfig,
        OrderConfig memory bobConfig,
        address aliceExpression,
        address bobExpression
    ) public {
        vm.assume(alice != bob);
        vm.assume(LibTestAddOrder.conformConfig(aliceConfig, iDeployer));
        vm.assume(LibTestAddOrder.conformConfig(bobConfig, iDeployer));
        (Order memory aliceOrder, bytes32 aliceOrderHash) = addOrderWithChecks(alice, aliceConfig, aliceExpression);
        (Order memory bobOrder, bytes32 bobOrderHash) = addOrderWithChecks(bob, bobConfig, bobExpression);
        (aliceOrder);
        (bobOrder);
        assertTrue(aliceOrderHash != bobOrderHash);
    }

    /// Alice can add orders with different configs. The resulting orders MUST
    /// be different.
    function testAddOrderSameAccountWithDifferentConfig(
        address alice,
        OrderConfig memory configOne,
        OrderConfig memory configTwo,
        address expressionOne,
        address expressionTwo
    ) public {
        vm.assume(LibTestAddOrder.conformConfig(configOne, iDeployer));
        vm.assume(LibTestAddOrder.conformConfig(configTwo, iDeployer));
        (Order memory expectedOrderOne, bytes32 expectedOrderOneHash) =
            LibTestAddOrder.expectedOrder(alice, configOne, iInterpreter, iStore, expressionOne);
        (Order memory expectedOrderTwo, bytes32 expectedOrderTwoHash) =
            LibTestAddOrder.expectedOrder(alice, configTwo, iInterpreter, iStore, expressionTwo);
        (expectedOrderOne);
        (expectedOrderTwo);
        assertTrue(expectedOrderOneHash != expectedOrderTwoHash);
        (Order memory orderOne, bytes32 orderOneHash) = addOrderWithChecks(alice, configOne, expressionOne);
        (Order memory orderTwo, bytes32 orderTwoHash) = addOrderWithChecks(alice, configTwo, expressionTwo);
        (orderOne);
        (orderTwo);
        assertTrue(orderOneHash != orderTwoHash);
    }
}