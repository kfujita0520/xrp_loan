/* eslint-disable */
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import hardhat from 'hardhat';
import { BigNumber } from 'ethers';
import { Result } from '@ethersproject/abi';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { decodeAccountID, encodeAccountID } from "ripple-address-codec";
import { XRPBridgeLoan, MyNFT, WXRP } from '../typechain';


const SECONDS_IN_A_HOUR = 3600;
const SECONDS_IN_A_DAY = 86400;
const SECONDS_IN_A_WEEK = 604800;
const SECONDS_IN_A_YEAR = 31449600;

const enum LoanStatus {
    Created = 0,
    Activated = 1,
    Started = 2,
    PrincipalRedeeming = 3,
    Redeemed = 4,
    Completed = 5,
    Cancelled = 6,
    Defaulted = 7
}





async function deployContract() {
  const [deployer, borrower, lender] = await hardhat.ethers.getSigners() as SignerWithAddress[];

  const WXRPContract = await ethers.getContractFactory("WXRP");
  const WXRP = await WXRPContract.deploy();
  await WXRP.deployed();
  console.log(`WXRP is deployed to ${WXRP.address}`);

  const MyNFTContract = await ethers.getContractFactory("MyNFT");
  const MyNFT = await MyNFTContract.deploy();
  await MyNFT.deployed();
  console.log(`MyNFT is deployed to ${MyNFT.address}`);


  return {
    deployer,
    borrower,
    lender,
    MyNFT: MyNFT,
    WXRP: WXRP
  };
}

async function sendEther(signer:SignerWithAddress, recipient: string, amount: BigNumber) {
    const transaction = {
        to: recipient,
        value: amount
    };

    const txResponse = await signer.sendTransaction(transaction);
    const txReceipt = await txResponse.wait(); // Wait for the transaction to be mined

    console.log(`Transaction ${txReceipt.transactionHash} mined in block ${txReceipt.blockNumber}`);
}

const xrplAccountToEvmAddress = (account: string): string => {
    const accountId = decodeAccountID(account);
    return `0x${accountId.toString("hex")}`;
};

const evmAddressToXrplAccount = (address: string): string => {
    const accountId = Buffer.from(address.slice(2), "hex");
    return encodeAccountID(accountId);
};


describe('XRP Bridge Loan', () => {

    let XRPBridgeLoan: XRPBridgeLoan;
    let MyNFT: MyNFT;
    let WXRP: WXRP;
    //let deployer: SignerWithAddress;
    let deployer: SignerWithAddress, borrower: SignerWithAddress, lender: SignerWithAddress;

    before(async ()=>{
        ({ deployer, borrower, lender, MyNFT, WXRP } = await deployContract());
        console.log('Deployer: ', deployer.address);
        console.log('Borrower: ', borrower.address);
        console.log('Lender: ', lender.address);
        console.log('Balance of Deployer: ', await ethers.provider.getBalance(deployer.address));
    });



    describe('Normal Lending Flow', () => {
        let XRPBridgeLoan: XRPBridgeLoan;
        let XRPborrower = "rE7b6ev9b64sr6XzMwMPS8A2iKsfpEKMyK";
        let XRPlender = "rUEbC1wEPSC8dQUP5R8z2bwGjVZWJ7Y4cS";

        before(async ()=>{
            const XRPBridgeLoanContract = await ethers.getContractFactory("XRPBridgeLoanTerm");
            XRPBridgeLoan = await XRPBridgeLoanContract.deploy(
                            WXRP.address, 
                            ethers.utils.parseEther("1000"),
                            SECONDS_IN_A_WEEK * 20, //20 weeks
                            1000, //10%
                            borrower.address,
                            lender.address, 
                            xrplAccountToEvmAddress(XRPborrower),
                            xrplAccountToEvmAddress(XRPlender),
                            "0x0FCCFB556B4aA1B44F31220AcDC8007D46514f31"//Bridge Door Native Contract Address
                        );
            await XRPBridgeLoan.deployed();
            console.log(`XRPBridgeLoan is deployed to ${XRPBridgeLoan.address}`);
            await sendEther(deployer, XRPBridgeLoan.address, ethers.utils.parseEther("20"));
        });

        it('deposit collateral', async () => {


            await MyNFT.safeMint(borrower.address);
            let tokenId = await MyNFT.nextTokenId() - 1 ;
            console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
            await MyNFT.connect(borrower).approve(XRPBridgeLoan.address, tokenId);
            await XRPBridgeLoan.connect(borrower).depositNFTCollateral(MyNFT.address, tokenId);
            console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
            expect(await MyNFT.ownerOf(tokenId)).to.equal(XRPBridgeLoan.address);
        });

        it('approve and lend', async () => {

            await XRPBridgeLoan.connect(lender).approveLoanTerm();
            console.log('Status: ', await XRPBridgeLoan.status());
            expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Activated);
            //NOTE: loan offer (payment) process on XRP Ledger is required. 
            console.log('Principal: ', await XRPBridgeLoan.principal());
            await XRPBridgeLoan.connect(lender).lend();
            console.log('lend has been completed');//TODO confirm event instead
            //NOTE: This is alternative method of xChainCommit from XRP Ledger which should be done in live-net test
            await sendEther(deployer, XRPBridgeLoan.address, await XRPBridgeLoan.totalAmount());
            console.log('Principal: ', await XRPBridgeLoan.principal());
            expect(await XRPBridgeLoan.principal()).to.equal(ethers.utils.parseEther("1000"));

        });

        it('start loan', async () => {
            let claimId: bigint = BigInt(25);//this is mock. in live test, should obtain from XRP Ledger
            await XRPBridgeLoan.connect(borrower).startBorrowing(claimId);
            expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Started);
            console.log('token balance of Loan Term contract: ', await ethers.provider.getBalance(XRPBridgeLoan.address));
            console.log("Start borrowing: ", await time.latest())
            await time.increase(SECONDS_IN_A_WEEK * 5 );
            console.log("10 Days has past: ", await time.latest());
            console.log(await XRPBridgeLoan.currentPrincipal());
            console.log(await XRPBridgeLoan.accruedInterest());
            console.log(await XRPBridgeLoan.claimableInterest());//2747252747252747252
            expect(await XRPBridgeLoan.claimableInterest()).to.be.equal(ethers.BigNumber.from("9615384615384615384"));
            //Borrower paid interest in advance
            await sendEther(borrower, XRPBridgeLoan.address, ethers.utils.parseEther("50"));

        });

        it('claim interest', async () => {
            let claimId = 26;
            let contractBal = await ethers.provider.getBalance(XRPBridgeLoan.address);
            await XRPBridgeLoan.connect(lender).claimInterest(claimId);
            expect(await XRPBridgeLoan.claimableInterest()).to.be.equal(ethers.BigNumber.from("0"));
            console.log(await XRPBridgeLoan.paidInterest());
            console.log(await ethers.provider.getBalance(XRPBridgeLoan.address));
            expect(await ethers.provider.getBalance(XRPBridgeLoan.address)).to.be.lessThan(contractBal);


        });

        it('redeem in full', async () => {
            await time.increase(SECONDS_IN_A_WEEK * 5 );
            //accrued interest will be half of previous period
            console.log('Claimable Interest: ', await XRPBridgeLoan.claimableInterest());
            expect(await XRPBridgeLoan.claimableInterest()).to.be.equal(ethers.BigNumber.from("9615384615384615385"));
            console.log('Accrued Interest for Borrower: ', await XRPBridgeLoan.accruedInterest());
            console.log('Paid Interest: ', await XRPBridgeLoan.paidInterest());
            console.log('balance of borrower: ', await ethers.provider.getBalance(borrower.address))
            console.log('balance of loan contract: ', await ethers.provider.getBalance(XRPBridgeLoan.address));
            console.log('NFT', await XRPBridgeLoan.collateral());
            let NFT_tokenId = (await XRPBridgeLoan.collateral()).tokenId

            await XRPBridgeLoan.connect(borrower).redeemPrincipal();
            expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.PrincipalRedeeming);

            //Deposit fund by manual for unit testing.
            await sendEther(borrower, XRPBridgeLoan.address, await XRPBridgeLoan.currentPrincipal());
            expect(await XRPBridgeLoan.currentPrincipal()).to.be.equal(ethers.utils.parseEther("0"));
            expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Redeemed);

            console.log('Withdrawable Principal: ', await XRPBridgeLoan.withdrawablePrincipal());
            expect(await XRPBridgeLoan.withdrawablePrincipal()).to.be.equal(ethers.utils.parseEther("1000"));
            console.log('Balance of loan contract: ', await ethers.provider.getBalance(XRPBridgeLoan.address));
            //NFT is withdrawn
            console.log('NFT', await XRPBridgeLoan.collateral());
            await XRPBridgeLoan.connect(borrower).withdrawCollateral();
            console.log('NFT', await XRPBridgeLoan.collateral());
            console.log('Owner of MyNFT', await MyNFT.ownerOf(NFT_tokenId));
            expect((await XRPBridgeLoan.collateral()).owner).to.be.equal(ethers.constants.AddressZero);
            expect(await MyNFT.ownerOf(NFT_tokenId)).to.be.equal(borrower.address);

        });

        it('complete by claim principal', async () => {
            console.log(await XRPBridgeLoan.accruedInterest());
            console.log(await XRPBridgeLoan.claimedInterest());
            
            let claimableInterest =  await XRPBridgeLoan.claimableInterest();
            await time.increase(SECONDS_IN_A_DAY * 5 );
            // no additional interest is accrued after full redemption
            expect(await XRPBridgeLoan.claimableInterest()).to.be.equal(claimableInterest);

            console.log('Claimable Interest: ', await XRPBridgeLoan.claimableInterest());
            console.log('Withdrawable principal: ', await XRPBridgeLoan.withdrawablePrincipal());
            console.log('Balance of loan contract: ', await ethers.provider.getBalance(XRPBridgeLoan.address));
            
            let claimId = 27;
            await XRPBridgeLoan.connect(lender).claimPrincipal(claimId);
            console.log('Withdrawable principal: ', await XRPBridgeLoan.withdrawablePrincipal());
            expect(await XRPBridgeLoan.withdrawablePrincipal()).to.be.equal(ethers.utils.parseEther("0"));
            
            claimId = 28;
            await XRPBridgeLoan.connect(lender).claimInterest(claimId);
            console.log('Claimable Interest: ', await XRPBridgeLoan.claimableInterest());
            expect(await XRPBridgeLoan.claimableInterest()).to.be.equal(ethers.utils.parseEther("0"));

            expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Completed);


        });





    });

    //Cancel, failed redemption
    describe('Side Scenario of Lending', () => {
        let XRPBridgeLoan: XRPBridgeLoan;
        let XRPborrower = "rE7b6ev9b64sr6XzMwMPS8A2iKsfpEKMyK";
        let XRPlender = "rUEbC1wEPSC8dQUP5R8z2bwGjVZWJ7Y4cS";

        beforeEach(async ()=>{
            const XRPBridgeLoanContract = await ethers.getContractFactory("XRPBridgeLoanTerm");
            XRPBridgeLoan = await XRPBridgeLoanContract.deploy(
                            WXRP.address, 
                            ethers.utils.parseEther("1000"),
                            SECONDS_IN_A_WEEK * 20, //20 weeks
                            1000, //10%
                            borrower.address,
                            lender.address, 
                            xrplAccountToEvmAddress(XRPborrower),
                            xrplAccountToEvmAddress(XRPlender),
                            "0x0FCCFB556B4aA1B44F31220AcDC8007D46514f31"//Bridge Door Native Contract Address
                        );
            await XRPBridgeLoan.deployed();
            console.log(`XRPBridgeLoan is deployed to ${XRPBridgeLoan.address}`);
            await sendEther(deployer, XRPBridgeLoan.address, ethers.utils.parseEther("20"));
            
            //deposit and approve
            await MyNFT.safeMint(borrower.address);
            let tokenId = await MyNFT.nextTokenId() - 1 ;
            console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
            await MyNFT.connect(borrower).approve(XRPBridgeLoan.address, tokenId);
            await XRPBridgeLoan.connect(borrower).depositNFTCollateral(MyNFT.address, tokenId);
            console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
            await XRPBridgeLoan.connect(lender).approveLoanTerm();
            console.log('Status: ', await XRPBridgeLoan.status());
            //NOTE: loan offer (payment) process on XRP Ledger is required. 
            console.log('Principal: ', await XRPBridgeLoan.principal());
            
            await XRPBridgeLoan.connect(lender).lend();
            console.log('lend has been completed');//TODO confirm event instead
            //NOTE: This is alternative method of xChainCommit from XRP Ledger which should be done in live-net test
            await sendEther(deployer, XRPBridgeLoan.address, await XRPBridgeLoan.totalAmount());
            console.log('Principal: ', await XRPBridgeLoan.principal());
        });

         

         it('Cancel Borrowing', async () => {

             let tokenId = (await XRPBridgeLoan.collateral()).tokenId;
             console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
             let claimId = 30;
             await XRPBridgeLoan.connect(borrower).cancelBorrowing(claimId);
             expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Cancelled);

             await XRPBridgeLoan.connect(borrower).withdrawCollateral();
             console.log('Owner of MyNFT', await MyNFT.ownerOf(tokenId));
             expect(await MyNFT.ownerOf(tokenId)).to.equal(borrower.address);

         });



         it('Liquidation', async () => {
              await time.increase(SECONDS_IN_A_WEEK * 21 );
              //TODO: check status, NFT liquidation by admin, fund return
              let tokenId = (await XRPBridgeLoan.collateral()).tokenId;
              console.log('Owner of MyNFT: ', await MyNFT.ownerOf(tokenId));
              console.log('Status: ', await XRPBridgeLoan.status());

              let claimId = 32;
              await XRPBridgeLoan.connect(lender).claimPrincipal(claimId);
              expect(await XRPBridgeLoan.status()).to.be.equal(LoanStatus.Defaulted);

              await XRPBridgeLoan.liquidateCollateral();
              console.log('Owner of MyNFT: ', await MyNFT.ownerOf(tokenId));
              expect(await MyNFT.ownerOf(tokenId)).to.equal(deployer.address);


         });



     });









});
