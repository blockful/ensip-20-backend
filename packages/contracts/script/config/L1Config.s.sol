// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ENSRegistry} from "@ens-contracts/registry/ENSRegistry.sol";
import {ReverseRegistrar} from
    "@ens-contracts/reverseRegistrar/ReverseRegistrar.sol";
import {NameWrapper} from "@ens-contracts/wrapper/NameWrapper.sol";
import {INameWrapper} from "@ens-contracts/wrapper/INameWrapper.sol";
import {UniversalResolver} from "@ens-contracts/utils/UniversalResolver.sol";
import {BaseRegistrarImplementation} from
    "@ens-contracts/ethregistrar/BaseRegistrarImplementation.sol";
import {MockMetadataService} from "../mocks/MetadataService.sol";
import {DummyOracle} from "@ens-contracts/ethregistrar/DummyOracle.sol";
import {
    StablePriceOracle,
    AggregatorInterface
} from "@ens-contracts/ethregistrar/StablePriceOracle.sol";
import {ETHRegistrarController} from
    "@ens-contracts/ethregistrar/ETHRegistrarController.sol";
import {PublicResolver} from "@ens-contracts/resolvers/PublicResolver.sol";

import {ENSHelper} from "../ENSHelper.sol";
import {DeployHelper} from "../DeployHelper.sol";
import {SubdomainController} from "../../src/SubdomainController.sol";

contract L1Config is Script, ENSHelper, DeployHelper {

    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 targetChainId;
        PublicResolver resolver;
        address registrar;
        INameWrapper nameWrapper;
    }

    constructor(uint256 chainId, address sender) {
        if (chainId == 11155111) activeNetworkConfig = _getSepoliaConfig();
        else if (chainId == 1) activeNetworkConfig = _getMainnetConfig();
        else activeNetworkConfig = _getAnvilConfig(sender);
    }

    function _getMainnetConfig() private view returns (NetworkConfig memory) {
        return NetworkConfig({
            targetChainId: 1,
            resolver: PublicResolver(getContractAddress("PublicResolver", 1)),
            registrar: getContractAddress("SubdomainController", 1),
            nameWrapper: NameWrapper(getContractAddress("NameWrapper", 1))
        });
    }

    function _getSepoliaConfig() private view returns (NetworkConfig memory) {
        return NetworkConfig({
            targetChainId: 11155111,
            resolver: PublicResolver(getContractAddress("PublicResolver", 11155111)),
            registrar: getContractAddress("SubdomainController", 11155111),
            nameWrapper: NameWrapper(getContractAddress("NameWrapper", 11155111))
        });
    }

    function _getAnvilConfig(address sender)
        private
        returns (NetworkConfig memory)
    {
        if (address(activeNetworkConfig.nameWrapper) != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast(sender);
        ENSRegistry registry = new ENSRegistry();

        string[] memory urls = new string[](0);
        UniversalResolver universalResolver =
            new UniversalResolver(address(registry), urls);

        ReverseRegistrar registrar = new ReverseRegistrar(registry);

        // .reverse
        registry.setSubnodeOwner(rootNode, labelhash("reverse"), sender);
        // addr.reverse
        registry.setSubnodeOwner(
            namehash("reverse"), labelhash("addr"), address(registrar)
        );

        BaseRegistrarImplementation baseRegistrar =
            new BaseRegistrarImplementation(registry, namehash("eth"));

        // .eth
        registry.setSubnodeOwner(
            rootNode, labelhash("eth"), address(baseRegistrar)
        );

        MockMetadataService metadata = new MockMetadataService(
            "http://ens-metadata-service.appspot.com/name/0x{id}"
        );
        NameWrapper nameWrapper =
            new NameWrapper(registry, baseRegistrar, metadata);
        baseRegistrar.addController(address(nameWrapper));

        DummyOracle dummyOracle = new DummyOracle(16 gwei);
        uint256[] memory rentPrices = new uint256[](5);
        rentPrices[0] = 5;
        rentPrices[1] = 4;
        rentPrices[2] = 3;
        rentPrices[3] = 2;
        rentPrices[4] = 1;
        StablePriceOracle priceOracle = new StablePriceOracle(
            AggregatorInterface(address(dummyOracle)), rentPrices
        );

        ETHRegistrarController registrarController = new ETHRegistrarController(
            baseRegistrar, priceOracle, 0, 1, registrar, nameWrapper, registry
        );
        nameWrapper.setController(address(registrarController), true);
        nameWrapper.setController(sender, true);

        uint256 subdomainPrice = 0.001 ether;
        SubdomainController subdomainController =
            new SubdomainController(address(nameWrapper), subdomainPrice);
        nameWrapper.setApprovalForAll(address(subdomainController), true);

        PublicResolver publicResolver = new PublicResolver(
            registry,
            nameWrapper,
            address(subdomainController),
            address(registrar)
        );

        registrar.setDefaultResolver(address(publicResolver));

        vm.stopBroadcast();

        console.log("Registry deployed at", address(registry));
        console.log("UniversalResolver deployed at", address(universalResolver));
        console.log("PublicResolver deployed at", address(publicResolver));
        console.log(
            "SubdomainController deployed at", address(subdomainController)
        );

        activeNetworkConfig = NetworkConfig({
            targetChainId: 31337,
            resolver: publicResolver,
            registrar: address(subdomainController),
            nameWrapper: nameWrapper
        });

        return activeNetworkConfig;
    }

}
