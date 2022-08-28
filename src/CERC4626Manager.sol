import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {RouterCrossTalk} from "router-crosstalk/RouterCrossTalk.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IRouterBridge, IRouterDepositExecute, ICERC4626Manager, ICERC4626Operator} from "./interfaces.sol";
import {RouterBase} from "./RouterBase.sol";

// This is deployed on the same chain as the original vault.
contract CERC4626Manager is RouterBase {
    ERC4626 public immutable VAULT;
    ERC20 public immutable ASSET;
    IRouterBridge public immutable BRIDGE;
    bytes32 public immutable RESOURCE_ID;
    ERC20 public immutable FEE_TOKEN;

    event Deposit(address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed receiver, uint256 assets, uint256 shares);

    constructor(
        ERC4626 _vault,
        address _handler,
        address _bridge,
        bytes32 _resourceId,
        ERC20 _feeToken
    ) RouterBase(_handler) {
        VAULT = _vault;
        ASSET = _vault.asset();
        BRIDGE = IRouterBridge(_bridge);
        RESOURCE_ID = _resourceId;
        FEE_TOKEN = _feeToken;
    }

    function _routerSyncHandler(bytes4 selector, bytes memory data)
        internal
        override
        returns (bool success, bytes memory ret)
    {
        (success, ret) = address(this).call(abi.encodePacked(selector, data));
    }

    // cross talk functions
    // --------------------

    function depositFor(
        address sender,
        address recipient,
        uint256 amount,
        uint8 destinationChain
    ) external isSelf returns (uint shares) {
        ASSET.approve(address(VAULT), amount);
        shares = VAULT.deposit(amount, recipient);
        emit Deposit(recipient, amount, shares);

        routerSend(
            destinationChain,
            bytes4(ICERC4626Operator.mintTo.selector),
            abi.encodeWithSelector(
                ICERC4626Operator.mintTo.selector,
                abi.encode(sender, recipient, shares, amount)
            ),
            3_000_000,
            100e9 // 100 gwei
        );
    }

    function withdrawTo(
        address sender,
        address recipient,
        address owner,
        uint256 shares,
        uint8 destinationChain
    ) external isSelf returns (uint amount) {
        uint amount = VAULT.redeem(shares, address(this), address(this));
        emit Withdraw(recipient, amount, shares);

        ASSET.approve(address(BRIDGE), amount);

        uint256[] memory flags = new uint256[](0);
        address[] memory path = new address[](0);
        bytes[] memory dataTx = new bytes[](0);

        BRIDGE.deposit(
            destinationChain,
            RESOURCE_ID,
            abi.encode(
                IRouterDepositExecute.DepositData({
                    srcTokenAmount: amount,
                    srcStableTokenAmount: amount,
                    destStableTokenAmount: amount,
                    destTokenAmount: amount,
                    isDestNative: false,
                    lenRecipientAddress: 20,
                    lenSrcTokenAddress: 20,
                    lenDestTokenAddress: 20,
                    widgetID: 0
                })
            ),
            flags,
            path,
            dataTx,
            address(FEE_TOKEN)
        );

        routerSend(
            destinationChain,
            ICERC4626Operator.burnAndWithdraw.selector,
            abi.encodeWithSelector(
                ICERC4626Operator.burnAndWithdraw.selector,
                abi.encode(sender, recipient, owner, shares, amount)
            ),
            300_000,
            100e9
        );
    }
}
