import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {RouterCrossTalk} from "router-crosstalk/RouterCrossTalk.sol";
import {RouterBase} from "./RouterBase.sol";

import {IRouterBridge, IRouterDepositExecute, ICERC4626Manager, ICERC4626Operator, chainIdToRouterChainId} from "./interfaces.sol";

contract CERC4626Operator is ERC4626, ICERC4626Operator, RouterBase {
    uint8 public immutable ORIGIN_CHAINID;
    IRouterBridge public immutable BRIDGE;
    bytes32 public immutable RESOURCE_ID;
    ERC20 public immutable FEE_TOKEN;

    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol,
        address _handler,
        uint8 originChain,
        IRouterBridge _bridge,
        bytes32 _resourceId,
        ERC20 _feeToken,
        address _manager
    ) ERC4626(asset, name, symbol) RouterBase(_handler) {
        ORIGIN_CHAINID = originChain;
        BRIDGE = _bridge;
        RESOURCE_ID = _resourceId;
        FEE_TOKEN = _feeToken;

        Chain2Addr[originChain] = _manager;
    }

    function _routerSyncHandler(bytes4 selector, bytes memory data)
        internal
        override
        returns (bool success, bytes memory ret)
    {
        (success, ret) = address(this).call(abi.encodePacked(selector, data));
    }

    function totalAssets() public view override returns (uint256) {
        return 0; // TODO
    }

    function _depositCrossChain(uint256 assets, address receiver) internal {
        uint256[] memory flags = new uint256[](0);
        address[] memory path = new address[](0);

        BRIDGE.deposit(
            ORIGIN_CHAINID,
            RESOURCE_ID,
            abi.encode(
                IRouterDepositExecute.DepositData({
                    srcTokenAmount: assets,
                    srcStableTokenAmount: assets,
                    destStableTokenAmount: assets,
                    destTokenAmount: assets,
                    isDestNative: false,
                    lenRecipientAddress: 20,
                    lenSrcTokenAddress: 20,
                    lenDestTokenAddress: 20,
                    widgetID: 0
                })
            ),
            flags,
            path,
            new bytes[](0),
            address(FEE_TOKEN)
        );

        routerSend(
            ORIGIN_CHAINID,
            bytes4(ICERC4626Manager.depositFor.selector),
            abi.encodeWithSelector(
                ICERC4626Manager.depositFor.selector,
                abi.encode(
                    msg.sender,
                    receiver,
                    assets,
                    chainIdToRouterChainId(block.chainid)
                )
            ),
            3_000_000,
            100e9 // 100 gwei
        );
    }

    function _withdrawCrossChain(
        address receiver,
        address owner,
        uint256 shares
    ) internal {
        routerSend(
            ORIGIN_CHAINID,
            bytes4(ICERC4626Manager.withdrawTo.selector),
            abi.encodeWithSelector(
                ICERC4626Manager.withdrawTo.selector,
                abi.encode(
                    msg.sender,
                    receiver,
                    owner,
                    shares,
                    chainIdToRouterChainId(block.chainid)
                )
            ),
            3_000_000,
            100e9 // 100 gwei
        );
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        _depositCrossChain(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        returns (uint256 assets)
    {
        require(
            false,
            "Minting fixed shares from cross chain is not possible rn"
        );
    }

    function redeem(
        uint shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        _withdrawCrossChain(receiver, owner, shares);
    }

    function withdraw(
        uint assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        require(
            false,
            "Withdrawing shares from cross chain is not possible rn"
        );
    }

    // cross talk functions
    // --------------------

    function mintTo(
        address sender,
        address receiver,
        uint256 shares,
        uint256 assets
    ) external isSelf {
        _mint(receiver, shares);
        emit Deposit(sender, receiver, assets, shares);
    }

    function burnAndWithdraw(
        address sender,
        address receiver,
        address owner,
        uint256 shares,
        uint256 assets
    ) external isSelf {
        _burn(receiver, shares);
        asset.transfer(receiver, assets);
        emit Withdraw(sender, receiver, owner, assets, shares);
    }
}
