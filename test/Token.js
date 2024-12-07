const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ServiceContract (Non-EAS Functions)", function () {
  let ServiceContract, serviceContract, owner, user, other;

  beforeEach(async function () {
    [owner, user, other] = await ethers.getSigners();

    // Deploy the contract with a mock EAS address
    const easMockAddress = "0x8525aefd3e65e4b4e91d503f5265ea769d0d02c05c859e6fca17f1794805105f";
    ServiceContract = await ethers.getContractFactory("ServiceContract");
    serviceContract = await ServiceContract.deploy(easMockAddress);
  });

  it("Should initialize with a valid EAS address", async function () {
    // Verify the constructor sets the EAS address correctly
    const easAddress = await serviceContract._eas();
    expect(easAddress).to.equal("0x8525aefd3e65e4b4e91d503f5265ea769d0d02c05c859e6fca17f1794805105f");
  });

  it("Should revert if metadata is empty during service registration", async function () {
    await expect(serviceContract.registerService("")).to.be.revertedWith("MetadataCannotBeEmpty");
  });

  it("Should register a service successfully and emit an event", async function () {
    await expect(serviceContract.registerService("Service 1"))
      .to.emit(serviceContract, "ServiceRegistered")
      .withArgs(owner.address, 1);

    const metadata = await serviceContract.getServiceMetadata(1);
    expect(metadata).to.equal("Service 1");
  });

  it("Should revert when fetching metadata for an invalid service ID", async function () {
    await expect(serviceContract.getServiceMetadata(999)).to.be.revertedWith("InvalidServiceId");
  });

  it("Should allow feedback submission for a valid service", async function () {
    await serviceContract.registerService("Service 1");

    await serviceContract.submitFeedback("Great service!", 1);
    const feedbacks = await serviceContract.getAllFeedbacks(1);
    expect(feedbacks).to.deep.equal(["Great service!"]);
  });

  it("Should revert when submitting feedback for an invalid service", async function () {
    await expect(serviceContract.submitFeedback("Feedback", 999)).to.be.revertedWith("InvalidServiceId");
  });

  it("Should fetch service IDs owned by a specific address", async function () {
    await serviceContract.registerService("Service 1");
    await serviceContract.registerService("Service 2");

    const serviceIds = await serviceContract.getServiceIdsByOwner(owner.address);
    expect(serviceIds.map((id) => id.toNumber())).to.deep.equal([1, 2]);
  });

  it("Should return the total number of feedbacks for a valid service", async function () {
    await serviceContract.registerService("Service 1");
    await serviceContract.submitFeedback("Feedback 1", 1);
    await serviceContract.submitFeedback("Feedback 2", 1);

    const feedbackCount = await serviceContract.getTotalFeedbacks(1);
    expect(feedbackCount).to.equal(2);
  });

  it("Should revert when fetching total feedbacks for an invalid service", async function () {
    await expect(serviceContract.getTotalFeedbacks(999)).to.be.revertedWith("InvalidServiceId");
  });
});
