const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("ConfidentialMath", function () {
  async function deployConfidentialMathFixture() {
    const [owner, user1, user2, unauthorizedUser] = await ethers.getSigners();

    const ConfidentialMath = await ethers.getContractFactory("ConfidentialMath");
    const confidentialMath = await ConfidentialMath.deploy();

    return { confidentialMath, owner, user1, user2, unauthorizedUser };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { confidentialMath } = await loadFixture(deployConfidentialMathFixture);
      expect(await confidentialMath.getAddress()).to.not.equal(ethers.ZeroAddress);
    });

    it("Should set owner as authorized decryptor", async function () {
      const { confidentialMath, owner } = await loadFixture(deployConfidentialMathFixture);
      expect(await confidentialMath.authorizedDecryptors(owner.address)).to.be.true;
    });
  });

  describe("Encryption", function () {
    it("Should encrypt amount successfully", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const tx = await confidentialMath.connect(user1).encryptAmount(amount, publicKey);
      const receipt = await tx.wait();

      // Check for EncryptionPerformed event
      const event = receipt.logs.find(log => 
        log.fragment && log.fragment.name === 'EncryptionPerformed'
      );
      expect(event).to.not.be.undefined;

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount, 
        publicKey
      );

      expect(encryptedAmount).to.not.equal(ethers.ZeroHash);
      expect(proof).to.not.equal(ethers.ZeroHash);
    });

    it("Should reject zero amount encryption", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const publicKey = ethers.randomBytes(32);

      await expect(
        confidentialMath.connect(user1).encryptAmount(0, publicKey)
      ).to.be.revertedWith("ConfidentialMath: Amount must be positive");
    });

    it("Should reject invalid public key", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      await expect(
        confidentialMath.connect(user1).encryptAmount(1000, ethers.ZeroHash)
      ).to.be.revertedWith("ConfidentialMath: Invalid public key");
    });

    it("Should reject amount exceeding maximum", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const maxValue = 2n ** 64n;
      const publicKey = ethers.randomBytes(32);

      await expect(
        confidentialMath.connect(user1).encryptAmount(maxValue, publicKey)
      ).to.be.revertedWith("ConfidentialMath: Amount exceeds maximum");
    });
  });

  describe("Verification", function () {
    it("Should verify correct encrypted amount", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      // First perform the actual encryption to store the data
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const isValid = await confidentialMath.verifyEncryptedAmount(
        encryptedAmount,
        amount,
        proof
      );

      expect(isValid).to.be.true;
    });

    it("Should reject verification with wrong amount", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const wrongAmount = 2000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const isValid = await confidentialMath.verifyEncryptedAmount(
        encryptedAmount,
        wrongAmount,
        proof
      );

      expect(isValid).to.be.false;
    });

    it("Should reject verification with inactive encrypted data", async function () {
      const { confidentialMath, user1, owner } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      // Deactivate the encrypted data
      await confidentialMath.connect(owner).deactivateEncryptedData(encryptedAmount);

      const isValid = await confidentialMath.verifyEncryptedAmount(
        encryptedAmount,
        amount,
        proof
      );

      expect(isValid).to.be.false;
    });
  });

  describe("Decryption", function () {
    it("Should allow authorized decryptor to decrypt", async function () {
      const { confidentialMath, user1, owner } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      // Owner is authorized by default
      const decryptedAmount = await confidentialMath.connect(owner).decryptAmount(
        encryptedAmount,
        proof
      );

      expect(decryptedAmount).to.be.a('bigint');
    });

    it("Should reject unauthorized decryption", async function () {
      const { confidentialMath, user1, unauthorizedUser } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount, proof] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      await expect(
        confidentialMath.connect(unauthorizedUser).decryptAmount(encryptedAmount, proof)
      ).to.be.revertedWith("ConfidentialMath: Not authorized for decryption");
    });

    it("Should reject decryption with invalid proof", async function () {
      const { confidentialMath, user1, owner } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const invalidProof = ethers.randomBytes(32);

      await expect(
        confidentialMath.connect(owner).decryptAmount(encryptedAmount, invalidProof)
      ).to.be.revertedWith("ConfidentialMath: Invalid decryption proof");
    });
  });

  describe("Homomorphic Operations", function () {
    it("Should perform homomorphic addition", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount1 = 1000;
      const amount2 = 2000;
      const publicKey1 = ethers.randomBytes(32);
      const publicKey2 = ethers.randomBytes(32);

      // Encrypt first amount
      const [encryptedAmount1] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount1,
        publicKey1
      );
      await confidentialMath.connect(user1).encryptAmount(amount1, publicKey1);

      // Encrypt second amount
      const [encryptedAmount2] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount2,
        publicKey2
      );
      await confidentialMath.connect(user1).encryptAmount(amount2, publicKey2);

      // Perform homomorphic addition
      const tx = await confidentialMath.connect(user1).homomorphicAdd(
        encryptedAmount1,
        encryptedAmount2
      );

      const receipt = await tx.wait();
      const event = receipt.logs.find(log => 
        log.fragment && log.fragment.name === 'HomomorphicOperationExecuted'
      );

      expect(event).to.not.be.undefined;
      expect(event.args[1]).to.equal("add");
    });

    it("Should add to public sum", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const currentSum = 5000;
      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const newSum = await confidentialMath.addToPublicSum(currentSum, encryptedAmount);

      expect(newSum).to.be.gt(currentSum);
    });

    it("Should perform homomorphic comparison", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount1 = 1000;
      const amount2 = 2000;
      const publicKey1 = ethers.randomBytes(32);
      const publicKey2 = ethers.randomBytes(32);

      // Encrypt amounts
      const [encryptedAmount1] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount1,
        publicKey1
      );
      await confidentialMath.connect(user1).encryptAmount(amount1, publicKey1);

      const [encryptedAmount2] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount2,
        publicKey2
      );
      await confidentialMath.connect(user1).encryptAmount(amount2, publicKey2);

      const tx = await confidentialMath.connect(user1).homomorphicCompare(
        encryptedAmount1,
        encryptedAmount2
      );

      const receipt = await tx.wait();
      const event = receipt.logs.find(log => 
        log.fragment && log.fragment.name === 'HomomorphicOperationExecuted'
      );

      expect(event).to.not.be.undefined;
      expect(event.args[1]).to.equal("compare");
    });
  });

  describe("Range Proofs", function () {
    it("Should generate range proof", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);
      const minValue = 500;
      const maxValue = 1500;

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const proofData = await confidentialMath.connect(user1).generateRangeProof(
        encryptedAmount,
        minValue,
        maxValue
      );

      expect(proofData).to.not.equal(ethers.ZeroHash);
    });

    it("Should verify valid range proof", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);
      const minValue = 500;
      const maxValue = 1500;

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const proofData = await confidentialMath.connect(user1).generateRangeProof.staticCall(
        encryptedAmount,
        minValue,
        maxValue
      );

      // Generate the actual proof
      await confidentialMath.connect(user1).generateRangeProof(
        encryptedAmount,
        minValue,
        maxValue
      );

      const isValid = await confidentialMath.verifyRangeProof(proofData);
      expect(isValid).to.be.true;
    });

    it("Should reject invalid range", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);
      const minValue = 1500; // Min > Max
      const maxValue = 500;

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      await expect(
        confidentialMath.connect(user1).generateRangeProof(
          encryptedAmount,
          minValue,
          maxValue
        )
      ).to.be.revertedWith("ConfidentialMath: Invalid range");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to add authorized decryptor", async function () {
      const { confidentialMath, owner, user1 } = await loadFixture(deployConfidentialMathFixture);

      await confidentialMath.connect(owner).addAuthorizedDecryptor(user1.address);
      expect(await confidentialMath.authorizedDecryptors(user1.address)).to.be.true;
    });

    it("Should allow owner to remove authorized decryptor", async function () {
      const { confidentialMath, owner, user1 } = await loadFixture(deployConfidentialMathFixture);

      await confidentialMath.connect(owner).addAuthorizedDecryptor(user1.address);
      await confidentialMath.connect(owner).removeAuthorizedDecryptor(user1.address);
      expect(await confidentialMath.authorizedDecryptors(user1.address)).to.be.false;
    });

    it("Should reject adding zero address as decryptor", async function () {
      const { confidentialMath, owner } = await loadFixture(deployConfidentialMathFixture);

      await expect(
        confidentialMath.connect(owner).addAuthorizedDecryptor(ethers.ZeroAddress)
      ).to.be.revertedWith("ConfidentialMath: Invalid decryptor address");
    });

    it("Should allow owner to invalidate proof", async function () {
      const { confidentialMath, user1, owner } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);
      const minValue = 500;
      const maxValue = 1500;

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const proofData = await confidentialMath.connect(user1).generateRangeProof.staticCall(
        encryptedAmount,
        minValue,
        maxValue
      );

      await confidentialMath.connect(user1).generateRangeProof(
        encryptedAmount,
        minValue,
        maxValue
      );

      // Proof should be valid initially
      expect(await confidentialMath.verifyRangeProof(proofData)).to.be.true;

      // Invalidate the proof
      await confidentialMath.connect(owner).invalidateProof(proofData);

      // Proof should now be invalid
      expect(await confidentialMath.verifyRangeProof(proofData)).to.be.false;
    });

    it("Should reject unauthorized admin operations", async function () {
      const { confidentialMath, user1, unauthorizedUser } = await loadFixture(deployConfidentialMathFixture);

      await expect(
        confidentialMath.connect(unauthorizedUser).addAuthorizedDecryptor(user1.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        confidentialMath.connect(unauthorizedUser).deactivateEncryptedData(ethers.randomBytes(32))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("View Functions", function () {
    it("Should return encrypted data", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const data = await confidentialMath.getEncryptedData(encryptedAmount);
      expect(data.creator).to.equal(user1.address);
      expect(data.isActive).to.be.true;
    });

    it("Should return user's encrypted data", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const userEncryptedData = await confidentialMath.getUserEncryptedData(user1.address);
      expect(userEncryptedData.length).to.equal(1);
    });

    it("Should validate encrypted data", async function () {
      const { confidentialMath, user1 } = await loadFixture(deployConfidentialMathFixture);

      const amount = 1000;
      const publicKey = ethers.randomBytes(32);

      const [encryptedAmount] = await confidentialMath.connect(user1).encryptAmount.staticCall(
        amount,
        publicKey
      );
      await confidentialMath.connect(user1).encryptAmount(amount, publicKey);

      const isValid = await confidentialMath.isEncryptedDataValid(encryptedAmount);
      expect(isValid).to.be.true;

      const invalidData = ethers.randomBytes(32);
      const isInvalid = await confidentialMath.isEncryptedDataValid(invalidData);
      expect(isInvalid).to.be.false;
    });
  });
});