import {RouterCrossTalk} from "router-crosstalk/RouterCrossTalk.sol";

abstract contract RouterBase is RouterCrossTalk {
    constructor(address _handler) RouterCrossTalk(_handler) {
        // default admin is the contract deployer
        admin = msg.sender;
    }

    address public admin;

    modifier onlyAdmin() {
        require(
            msg.sender == admin || msg.sender == address(this),
            "OnlyAdmin"
        );
        _;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setLinkAsAdmin(uint8 chain, address _link) external onlyAdmin {
        Chain2Addr[chain] = _link;
    }
}
