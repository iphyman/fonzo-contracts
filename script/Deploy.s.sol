// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {FonzoMarket} from "../src/FonzoMarket.sol";

contract Deploy is Script {
    struct DeploymentParams {
        address owner;
        address ftsoV2;
    }

    function readEnvFile() internal view returns (DeploymentParams memory params) {
        // FTSOV2 oracle address on the deployment network
        params.ftsoV2 = vm.envAddress("FTSO_V2_ORACLE_ADDRESS");
        require(params.ftsoV2 != address(0), "Invalid oracle address");

        params.owner = vm.envAddress("OWNER");
        require(params.owner != address(0), "Owner not set");
    }

    function run() public {
        DeploymentParams memory params = readEnvFile();

        vm.startBroadcast();
        new FonzoMarket(params.owner, params.ftsoV2);
        vm.stopBroadcast();
    }
}
