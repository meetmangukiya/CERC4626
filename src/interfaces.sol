import {ERC20} from "solmate/tokens/ERC20.sol";

interface IRouterBridge {
    function deposit(
        uint8 destinationChainID,
        bytes32 resourceID,
        bytes calldata data,
        uint256[] memory flags,
        address[] memory path,
        bytes[] calldata dataTx,
        address feeTokenAddress
    ) external;
}

interface IRouterDepositExecute {
    struct SwapInfo {
        address feeTokenAddress;
        uint64 depositNonce;
        uint256 index;
        uint256 returnAmount;
        address recipient;
        address stableTokenAddress;
        address handler;
        uint256 srcTokenAmount;
        uint256 srcStableTokenAmount;
        uint256 destStableTokenAmount;
        uint256 destTokenAmount;
        uint256 lenRecipientAddress;
        uint256 lenSrcTokenAddress;
        uint256 lenDestTokenAddress;
        bytes20 srcTokenAddress;
        address srcStableTokenAddress;
        bytes20 destTokenAddress;
        address destStableTokenAddress;
        bytes[] dataTx;
        uint256[] flags;
        address[] path;
        address depositer;
        bool isDestNative;
        uint256 widgetID;
    }

    struct DepositData {
        uint256 srcTokenAmount;
        uint256 srcStableTokenAmount;
        uint256 destStableTokenAmount;
        uint256 destTokenAmount;
        bool isDestNative;
        uint256 lenRecipientAddress;
        uint256 lenSrcTokenAddress;
        uint256 lenDestTokenAddress;
        uint256 widgetID;
    }

    /**
        @notice It is intended that deposit are made using the Bridge contract.
        @param destinationChainID Chain ID deposit is expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @param swapDetails Swap details

     */
    function deposit(
        bytes32 resourceID,
        uint8 destinationChainID,
        uint64 depositNonce,
        SwapInfo calldata swapDetails
    ) external;

    /**
        @notice It is intended that proposals are executed by the Bridge contract.
     */
    function executeProposal(SwapInfo calldata swapDetails, bytes32 resourceID)
        external
        returns (address, uint256);
}

interface ICERC4626Manager {
    function depositFor(
        address recipient,
        uint256 amount,
        uint8 destinationChain
    ) external;

    function withdrawTo(
        address recipient,
        uint256 shares,
        uint8 destinationChain
    ) external;
}

interface ICERC4626Operator {
    function mintTo(
        address sender,
        address receiver,
        uint256 shares,
        uint256 assets
    ) external;

    function burnAndWithdraw(
        address sender,
        address receiver,
        address owner,
        uint256 shares,
        uint256 assets
    ) external;
}

// https://dev.routerprotocol.com/important-parameters/supported-chains
function chainIdToRouterChainId(uint chainId)
    pure
    returns (uint routerChainId)
{
    if (chainId == 1) {
        routerChainId = 7;
    } else if (chainId == 10) {
        routerChainId = 6;
    } else if (chainId == 25) {
        routerChainId = 10;
    } else if (chainId == 56) {
        routerChainId = 2;
    } else if (chainId == 137) {
        routerChainId = 1;
    } else if (chainId == 250) {
        routerChainId = 4;
    } else if (chainId == 42161) {
        routerChainId = 5;
    } else if (chainId == 43114) {
        routerChainId = 3;
    } else if (chainId == 1313161554) {
        routerChainId = 9;
    } else if (chainId == 1666600000) {
        routerChainId = 8;
    } else {
        routerChainId = 0; // unknown
    }
}

function getBridgeContractAddress(uint chainId) pure returns (address bridge) {
    if (chainId == 2) {
        bridge = 0xf18aCC02628009231d7BAAF9a7a24C0860Dda6cb;
    }
}

interface ICERC4626Factory {
    function deployOperator(
        ERC20 _asset,
        uint256 fromChainId,
        address _managerAddress,
        bytes32 _resourceId,
        ERC20 _feeToken,
        string calldata name,
        string calldata symbol
    ) external;
}
