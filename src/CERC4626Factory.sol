import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {RouterCrossTalk} from "router-crosstalk/RouterCrossTalk.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {CERC4626Manager} from "./CERC4626Manager.sol";
import {CERC4626Operator} from "./CERC4626Operator.sol";
import {chainIdToRouterChainId, IRouterBridge, ICERC4626Factory} from "./interfaces.sol";
import {RouterBase} from "./RouterBase.sol";

contract CERC4626Factory is RouterBase, ICERC4626Factory {
    event ManagerCreated(
        address indexed vault,
        address indexed manager,
        bytes32 resourceId,
        address feeToken,
        uint256 destinationChainId,
        uint8 routerChainId
    );
    event OperatorCreated(
        address indexed asset,
        address indexed operator,
        uint256 originChainId,
        uint8 routerChainId,
        bytes32 resourceId,
        address feeToken
    );

    address public immutable BRIDGE;

    ERC20 public immutable FEE_TOKEN;

    constructor(
        address _handler,
        address _bridge,
        ERC20 _feeToken
    ) RouterBase(_handler) {
        BRIDGE = _bridge;
        FEE_TOKEN = _feeToken;
        FEE_TOKEN.approve(_handler, type(uint).max);
    }

    function _routerSyncHandler(bytes4 selector, bytes memory _data)
        internal
        override
        returns (bool success, bytes memory ret)
    {
        (success, ret) = address(this).call(abi.encodePacked(selector, _data));
    }

    function crosschainify(
        ERC4626 _vault,
        bytes32 _resourceId,
        ERC20 _feeToken,
        uint256 _destinationChainId,
        address _destinationChainAsset,
        address _destinationFeeToken
    ) external returns (CERC4626Manager manager) {
        address genericHandler = _getHandler();
        manager = new CERC4626Manager(
            _vault,
            genericHandler,
            BRIDGE,
            _resourceId,
            _feeToken
        );

        uint8 routerChainId = uint8(
            chainIdToRouterChainId(_destinationChainId)
        );
        emit ManagerCreated(
            address(_vault),
            address(manager),
            _resourceId,
            address(_feeToken),
            _destinationChainId,
            routerChainId
        );

        string memory name = string(
            abi.encodePacked("CERC4626Operator ", _vault.name())
        );
        string memory symbol = string(abi.encodePacked("co_", _vault.symbol()));

        routerSend(
            routerChainId,
            ICERC4626Factory.deployOperator.selector,
            abi.encodeWithSelector(
                ICERC4626Factory.deployOperator.selector,
                abi.encode(
                    _destinationChainAsset,
                    block.chainid,
                    address(manager),
                    _resourceId, // NOTE: assumption resourceid is same on every chain
                    _destinationFeeToken,
                    name,
                    symbol
                )
            ),
            500_000,
            100e9
        );
    }

    function _getHandler() internal view returns (address handler) {
        (bool success, bytes memory ret) = address(this).staticcall(
            abi.encodeWithSignature("fetchHandler()")
        );
        require(success, "_getHandler failed");
        handler = abi.decode(ret, (address));
    }

    function deployOperator(
        ERC20 _asset,
        uint256 fromChainId,
        address _managerAddress,
        bytes32 _resourceId,
        ERC20 _feeToken,
        string calldata name,
        string calldata symbol
    ) external isSelf {
        address handler = _getHandler();
        uint8 routerChainId = uint8(chainIdToRouterChainId(fromChainId));

        CERC4626Operator operator = new CERC4626Operator(
            _asset,
            name,
            symbol,
            handler,
            routerChainId,
            IRouterBridge(BRIDGE),
            _resourceId,
            _feeToken,
            _managerAddress
        );

        emit OperatorCreated(
            address(_asset),
            address(operator),
            fromChainId,
            routerChainId,
            _resourceId,
            address(_feeToken)
        );
    }
}
