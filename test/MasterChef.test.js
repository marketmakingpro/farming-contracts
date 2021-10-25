const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const MasterChef = artifacts.require('MasterChef');
const Referral = artifacts.require('Referral');
const MMPROtoken = artifacts.require('MMPROtoken');
const MockERC20 = artifacts.require('MockERC20');
var BN = web3.utils.BN;

contract('MasterChef', ([owner, referrer, user, fee, minter]) => {
    
    beforeEach(async () => {
        this.mmptoken = await MMPROtoken.new({ from: owner });
        this.referral = await Referral.new({ from: owner });
        this.chef = await MasterChef.new(this.mmptoken.address,'0', fee, { from: owner });
        this.referral.updateOperator(this.chef.address, true,{ from: owner });
        await this.chef.setReferralAddress(this.referral.address,{from: owner });
        await this.mmptoken.transferOwnership(this.chef.address, { from: owner });
        this.lp = await MockERC20.new('LPToken', 'LP', web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.lp.transfer(user, web3.utils.toWei("100", "ether"), { from: minter });
        

    });

    it('TEST 1', async () => {

        await this.chef.add('100', this.lp.address,'100', 0, '0x0000000000000000000000000000000000000000',0,{from: owner });
        await this.lp.approve(this.chef.address, web3.utils.toWei("100", "ether"), { from: user });
        const latestBlock = await time.latestBlock();
        const endBlock = latestBlock.add(new BN('10')).toString();
        console.log("farming from ",latestBlock.toString()," block to ", endBlock," block");
        await this.chef.deposit(0, web3.utils.toWei("100", "ether"), referrer, { from: user });
        await time.advanceBlockTo(endBlock);
        await this.chef.withdraw(0, web3.utils.toWei("99", "ether"), { from: user });

        expect(web3.utils.fromWei(await this.lp.balanceOf(user))).to.equal("99");
        expect(web3.utils.fromWei(await this.lp.balanceOf(fee))).to.equal("1");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(user))).to.equal("9.99999999999999999");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(referrer))).to.equal("0.499999999999999999");

    });

    it('TEST 2', async () => {
        this.doubleToken = await MockERC20.new('doubleToken', 'DBT', web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.doubleToken.transfer(this.chef.address, web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.chef.add('100', this.lp.address,'100', 1, this.doubleToken.address,web3.utils.toWei("100000000", "ether"),{from: owner });
        await this.lp.approve(this.chef.address, web3.utils.toWei("100", "ether"), { from: user });

        const latestBlock = await time.latestBlock();
        const endBlock = latestBlock.add(new BN('10')).toString();
        console.log("farming from ",latestBlock.toString()," block to ", endBlock," block");
        await this.chef.deposit(0, web3.utils.toWei("100", "ether"), referrer, { from: user });
        await time.advanceBlockTo(endBlock);
        await this.chef.withdraw(0, web3.utils.toWei("99", "ether"), { from: user });


        expect(web3.utils.fromWei(await this.lp.balanceOf(user))).to.equal("99");
        expect(web3.utils.fromWei(await this.lp.balanceOf(fee))).to.equal("1");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(user))).to.equal("9.99999999999999999");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(referrer))).to.equal("0.499999999999999999");
        expect(web3.utils.fromWei(await this.doubleToken.balanceOf(user))).to.equal("999999999.99999999999999999");
        expect(web3.utils.fromWei(await this.doubleToken.balanceOf(referrer))).to.equal("49999999.999999999999999999");

        //console.log("  MasterChef address баланс MMPROtoken:",web3.utils.fromWei(await this.mmptoken.balanceOf(this.chef.address)));
        
        
    });

    it('TEST 3', async () => {
        this.MultiFarmToken1 = await MockERC20.new('MultiFarmToken1', 'MLT1', web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.MultiFarmToken1.transfer(this.chef.address, web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.chef.addMultiFarmToken(this.MultiFarmToken1.address, web3.utils.toWei("1000000", "ether"),{from: owner });

        this.MultiFarmToken2 = await MockERC20.new('MultiFarmToken2', 'MLT2', web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.MultiFarmToken2.transfer(this.chef.address, web3.utils.toWei("10000000000", "ether"), { from: minter });
        await this.chef.addMultiFarmToken(this.MultiFarmToken2.address, web3.utils.toWei("1000000", "ether"),{from: owner });

        await this.chef.add('100', this.lp.address,'100', 2, '0x0000000000000000000000000000000000000000',0,{from: owner });
        

        await this.lp.approve(this.chef.address, web3.utils.toWei("100", "ether"), { from: user });

        const latestBlock = await time.latestBlock();
        const endBlock = latestBlock.add(new BN('10')).toString();
        console.log("farming from ",latestBlock.toString()," block to ", endBlock," block");
        await this.chef.deposit(0, web3.utils.toWei("100", "ether"), referrer, { from: user });
        await time.advanceBlockTo(endBlock);
        await this.chef.withdraw(0, web3.utils.toWei("99", "ether"), { from: user });

        expect(web3.utils.fromWei(await this.lp.balanceOf(user))).to.equal("99");
        expect(web3.utils.fromWei(await this.lp.balanceOf(fee))).to.equal("1");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(user))).to.equal("9.99999999999999999");
        expect(web3.utils.fromWei(await this.mmptoken.balanceOf(referrer))).to.equal("0.499999999999999999");
        expect(web3.utils.fromWei(await this.MultiFarmToken1.balanceOf(user))).to.equal("9999999.99999999999999999");
        expect(web3.utils.fromWei(await this.MultiFarmToken1.balanceOf(referrer))).to.equal("499999.999999999999999999");
        expect(web3.utils.fromWei(await this.MultiFarmToken2.balanceOf(user))).to.equal("9999999.99999999999999999");
        expect(web3.utils.fromWei(await this.MultiFarmToken2.balanceOf(referrer))).to.equal("499999.999999999999999999");
        
        
    });
});