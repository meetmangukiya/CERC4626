import {Test} from "forge-std/Test.sol";
import {CERC4626Manager} from "../src/CERC4626Manager.sol";
import {CERC4626Operator} from "../src/CERC4626Operator.sol";
import {CERC4626Factory} from "../src/CERC4626Factory.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {chainIdToRouterChainId} from "../src/interfaces.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {AaveV3ERC4626, IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract CERC4626Test is Test {
    CERC4626Factory arbitrumFactory;
    CERC4626Factory optimismFactory;

    CERC4626Manager manager;
    CERC4626Operator operator;

    uint arbitrumForkId;
    uint optimismForkId;

    ERC4626 targetVault = ERC4626(0xf18aCC02628009231d7BAAF9a7a24C0860Dda6cb);

    ERC20 arbitrumUSDC = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    ERC20 optimismUSDC = ERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

    address arbitrumBridge = 0xf18aCC02628009231d7BAAF9a7a24C0860Dda6cb;
    address optimismBridge = 0xf18aCC02628009231d7BAAF9a7a24C0860Dda6cb;

    address arbitrumHandler = 0x2d20237561E30729BbD623E9b8e9293bb8a78746;
    address optimismHandler = 0x33D9291CC2Eaabebd011D76765526f0C4c7ffe86;

    bytes32 resourceId =
        0x00000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa8417400;

    uint256 arbitrumChainId;
    uint256 optimismChainId;

    function setUp() public {
        arbitrumForkId = vm.createFork("https://arb1.arbitrum.io/rpc");
        optimismForkId = vm.createFork("https://mainnet.optimism.io");

        vm.selectFork(arbitrumForkId);
        arbitrumChainId = block.chainid;
        arbitrumFactory = new CERC4626Factory(
            arbitrumHandler,
            arbitrumBridge,
            arbitrumUSDC
        );
        deal(address(arbitrumUSDC), address(arbitrumFactory), 100e6);

        vm.selectFork(optimismForkId);
        optimismChainId = block.chainid;
        optimismFactory = new CERC4626Factory(
            optimismHandler,
            optimismBridge,
            optimismUSDC
        );
        optimismFactory.setLinkAsAdmin(
            uint8(chainIdToRouterChainId(arbitrumChainId)),
            address(arbitrumFactory)
        );

        vm.selectFork(arbitrumForkId);
        arbitrumFactory.setLinkAsAdmin(
            uint8(chainIdToRouterChainId(optimismChainId)),
            address(optimismFactory)
        );

        vm.selectFork(arbitrumForkId);
        AaveV3ERC4626 aaveUSDC = new AaveV3ERC4626(
            arbitrumUSDC,
            ERC20(0x625E7708f30cA75bfd92586e17077590C60eb4cD),
            IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
            address(this),
            IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e)
        );
        targetVault = aaveUSDC;

        emit log_address(
            arbitrumFactory.fetchLink(
                uint8(chainIdToRouterChainId(optimismChainId))
            )
        );
        CERC4626Manager manager = arbitrumFactory.crosschainify(
            targetVault,
            resourceId,
            arbitrumUSDC,
            optimismChainId,
            address(optimismUSDC),
            address(optimismUSDC)
        );

        vm.selectFork(optimismForkId);
        // router node tx
        vm.prank(optimismHandler);
        bytes memory deployOperatorCalldata = abi.encode(
            optimismUSDC, // ERC20 _asset,
            arbitrumChainId, // uint256 fromChainId,
            address(manager), // address _managerAddress,
            resourceId, // bytes32 _resourceId,
            optimismUSDC, // ERC20 _feeToken,
            "", // string calldata name,
            "" // string calldata symbol
        );
        optimismFactory.routerSync(0, address(0x0), deployOperatorCalldata); // TODO
    }

    function testDeposit() external {}
}
