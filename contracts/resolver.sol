// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import { SchemaResolver } from "https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/resolver/SchemaResolver.sol";

import { IEAS, Attestation } from "https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/IEAS.sol";

contract AttesterResolver is SchemaResolver {
    uint256 private serviceIdCounter = 1;

    struct Service {
        string metadata;
        address owner;
    }

    struct EncryptedFeedback {
        string ciphertext;
        uint256 dataToEncryptHash;
    }

    mapping(uint256 => Service) private services;
    mapping(uint256 => EncryptedFeedback[]) private serviceToEncryptedFeedbacks;

    event ServiceRegistered(address indexed owner, uint256 serviceId);

    constructor(IEAS eas) SchemaResolver(eas) {}

    function registerService(string memory _metadata) external returns (uint256) {
        require(bytes(_metadata).length > 0, "Metadata cannot be empty");
        uint256 currentServiceId = serviceIdCounter++;
        services[currentServiceId] = Service({
            metadata: _metadata,
            owner: msg.sender
        });

        emit ServiceRegistered(msg.sender, currentServiceId);
        return currentServiceId;
    }

    function submitFeedback(string memory _ciphertext, uint256 _dataToEncryptHash, uint256 _serviceId) external {
        require(bytes(_ciphertext).length > 0, "Ciphertext cannot be empty");
        require(_serviceId < serviceIdCounter, "Invalid service ID");

        EncryptedFeedback memory feedback = EncryptedFeedback({
            ciphertext: _ciphertext,
            dataToEncryptHash: _dataToEncryptHash
        });
        serviceToEncryptedFeedbacks[_serviceId].push(feedback);
    }

    function getServiceIdsByOwner(address _owner) public view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i < serviceIdCounter; i++) {
            if (services[i].owner == _owner) {
                count++;
            }
        }

        uint256[] memory serviceIds = new uint256[](count);
        count = 0;
        for (uint256 i = 1; i < serviceIdCounter; i++) {
            if (services[i].owner == _owner) {
                serviceIds[count] = i;
                count++;
            }
        }
        return serviceIds;
    }

    function getServiceMetadata(uint256 _serviceId) external view returns (string memory) {
        require(_serviceId < serviceIdCounter, "Invalid service ID");
        return services[_serviceId].metadata;
     }

    function getTotalFeedbacks(uint256 _serviceId) public view returns (uint256) {
        require(_serviceId < serviceIdCounter, "Invalid service ID");
        return serviceToEncryptedFeedbacks[_serviceId].length;
    }

    function getAllFeedbacks(uint256 _serviceId) external view returns (EncryptedFeedback[] memory) {
        require(_serviceId < serviceIdCounter, "Invalid service ID");
        return serviceToEncryptedFeedbacks[_serviceId];
    }

    function onAttest(Attestation calldata attestation, uint256 /*value*/) internal view override returns (bool) {
        require(attestation.data.length == 64, "Invalid attestation data length");
        uint256 serviceId = abi.decode(attestation.data, (uint256));
        require(serviceId < serviceIdCounter, "Service not registered!");

        address sender = attestation.attester;
        require(services[serviceId].owner == sender, "Only the service owner can attest");
        return true;
    }

    function onRevoke(Attestation calldata /*attestation*/, uint256 /*value*/) internal pure override returns (bool) {
        // Placeholder for revoke logic if needed
        return true;
    }
}
