// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ENSRegistry} from "@ens-contracts/registry/ENSRegistry.sol";
import {ReverseRegistrar} from
    "@ens-contracts/reverseRegistrar/ReverseRegistrar.sol";
import {PublicResolver} from "@ens-contracts/resolvers/PublicResolver.sol";

import {L1Verifier} from "@evmgateway/L1Verifier.sol";
import {ENSHelper} from "../ENSHelper.sol";
import {L1Resolver} from "../../src/L1Resolver.sol";
import {L1Config} from "../config/L1Config.s.sol";

contract L1ResolverScript is Script, ENSHelper {

    function run() external {
        (
            ENSRegistry registry,
            uint256 targetChainId,
            PublicResolver resolver,
            address registrar,
            address nameWrapper
        ) = (new L1Config(block.chainid, msg.sender)).activeNetworkConfig();

        string[] memory urls = new string[](1);
        urls[0] = "http://127.0.0.1:3000/{sender}/{data}.json";

        string memory metadataUrl = "https://localhost:3000";

        vm.startBroadcast();

        L1Verifier verifier = new L1Verifier(urls);
        L1Resolver l1resolver = new L1Resolver(
            targetChainId,
            address(resolver),
            registrar,
            nameWrapper,
            verifier,
            metadataUrl
        );

        // .eth
        registry.setSubnodeOwner(rootNode, labelhash("eth"), msg.sender);
        // blockful.eth
        registry.setSubnodeRecord(
            namehash("eth"),
            labelhash("blockful"),
            msg.sender,
            address(l1resolver),
            100000
        );
        resolver.setAddr(namehash("blockful.eth"), msg.sender);
        resolver.setText(namehash("blockful.eth"), "com.twitter", "@blockful");

        vm.stopBroadcast();

        console.log("L1Resolver deployed at", address(l1resolver));
    }

}
