// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEAS, AttestationRequest, AttestationRequestData } from "https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/IEAS.sol";
import { NO_EXPIRATION_TIME, EMPTY_UID } from "https://github.com/ethereum-attestation-service/eas-contracts/blob/master/contracts/Common.sol";

contract ServiceContract {
    // Constants
    bytes32 private constant INTERACTION_SCHEMA_UID = 0x0353438abb8fc94491aa6c3629823c9ddcd0d7b28df6aa9a5281bbb5ff3bb6bb;
    bytes32 private constant REWARD_SCHEMA_UID = 0x8525aefd3e65e4b4e91d503f5265ea769d0d02c05c859e6fca17f1794805105f;

    // Immutable Variables
    IEAS private immutable _eas;

    // State Variables
    uint256 private serviceIdCounter = 1;

    struct Service {
        string metadata;
        address owner;
    }

    mapping(uint256 => Service) private services;
    mapping(uint256 => string[]) private serviceToFeedbacks;
    mapping(uint256 => uint256) private serviceToInteractions;

    // Events
    event ServiceRegistered(address indexed owner, uint256 serviceId);
    event AttestationCreated(bytes32 indexed attestationId);

    // Errors
    error InvalidEAS();
    error InvalidServiceId();
    error MetadataCannotBeEmpty();
    error FeedbackCannotBeEmpty();

    // Constructor
    constructor(IEAS eas) {
        if (address(eas) == address(0)) {
            revert InvalidEAS();
        }
        _eas = eas;
    }

    // Functions

    /// @notice Registers a new service with metadata.
    /// @param _metadata Metadata for the service.
    /// @return serviceId The unique ID of the registered service.
    function reegistrService(string memory _metadata) external returns (uint256) {
        if (bytes(_metadata).length == 0) {
            revert MetadataCannotBeEmpty();
        }

        uint256 serviceId = serviceIdCounter++;
        services[serviceId] = Service({
            metadata: _metadata,
            owner: msg.sender
        });

        emit ServiceRegistered(msg.sender, serviceId);
        return serviceId;
    }

    /// @notice Submits feedback for a specific service.
    /// @param feedback The feedback text.
    /// @param _serviceId The ID of the service.
    function submitFeedback(string memory feedback, uint256 _serviceId) external {
        if (bytes(feedback).length == 0) {
            revert FeedbackCannotBeEmpty();
        }
        if (_serviceId >= serviceIdCounter) {
            revert InvalidServiceId();
        }

        serviceToFeedbacks[_serviceId].push(feedback);
    }

    /// @notice Gets service IDs owned by a specific address.
    /// @param _owner The address of the owner.
    /// @return serviceIds Array of service IDs.
    function getServiceIdsByOwner(address _owner) public view returns (uint256[] memory) {
        uint256 count;

        for (uint256 i = 1; i < serviceIdCounter; i++) {
            if (services[i].owner == _owner) {
                count++;
            }
        }

        uint256[] memory serviceIds = new uint256[](count);
        count = 0;

        for (uint256 i = 1; i < serviceIdCounter; i++) {
            if (services[i].owner == _owner) {
                serviceIds[count++] = i;
            }
        }
        return serviceIds;
    }

    /// @notice Gets metadata of a service by ID.
    /// @param _serviceId The service ID.
    /// @return Metadata string.
    function getServiceMetadata(uint256 _serviceId) external view returns (string memory) {
        if (_serviceId >= serviceIdCounter) {
            revert InvalidServiceId();
        }
        return services[_serviceId].metadata;
    }

    /// @notice Gets the total number of feedback entries for a service.
    /// @param _serviceId The service ID.
    /// @return Total feedback count.
    function getTotalFeedbacks(uint256 _serviceId) public view returns (uint256) {
        if (_serviceId >= serviceIdCounter) {
            revert InvalidServiceId();
        }
        return serviceToFeedbacks[_serviceId].length;
    }

    /// @notice Gets all feedback for a service.
    /// @param _serviceId The service ID.
    /// @return feedbacks Array of feedback strings.
    function getAllFeedbacks(uint256 _serviceId) external view returns (string[] memory) {
        if (_serviceId >= serviceIdCounter) {
            revert InvalidServiceId();
        }
        return serviceToFeedbacks[_serviceId];
    }

    function getTotalInteractions(uint256 _serviceId) external view returns (uint256) {
        if (_serviceId >= serviceIdCounter) {
            revert InvalidServiceId();
        }
        return serviceToInteractions[_serviceId];
    }

    /// @notice Attests an interaction for a user and service.
    /// @param user The address of the user.
    /// @param serviceId The service ID.
    /// @return attestationId The ID of the created attestation.
    function attestInteraction(address user, uint256 serviceId) external returns (bytes32) {
        serviceToInteractions[serviceId]++;
        bytes32 attestationId = _eas.attest(
            AttestationRequest({
                schema: INTERACTION_SCHEMA_UID,
                data: AttestationRequestData({
                    recipient: user,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: true,
                    refUID: EMPTY_UID,
                    data: abi.encode(serviceId),
                    value: 0
                })
            })
        );

        emit AttestationCreated(attestationId);
        return attestationId;
    }

    /// @notice Attests a reward for a user and transfers the reward.
    /// @param user The address of the user.
    /// @param amount The reward amount.
    /// @return attestationId The ID of the created attestation.
    function attestRewardAndPay(address user, uint256 amount) external payable returns (bytes32) {
        require(msg.value >= amount, "Insufficient funds sent for reward");
        payable(user).transfer(amount);

        bytes32 attestationId = _eas.attest(
            AttestationRequest({
                schema: REWARD_SCHEMA_UID,
                data: AttestationRequestData({
                    recipient: user,
                    expirationTime: NO_EXPIRATION_TIME,
                    revocable: true,
                    refUID: EMPTY_UID,
                    data: abi.encode(amount),
                    value: 0
                })
            })
        );

        emit AttestationCreated(attestationId);
        return attestationId;
    }
}
