// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/Ownable.sol";
import "./lib/SafeMath.sol";
import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/ReentrancyGuard.sol";
import "./IReferral.sol";



contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 rewardDoubleDebt;
    
        mapping(address =>uint256) multiRewardDebt; // multi rewards func 
    }
    
    struct AdditionalPoolInfo {
        IERC20 token;
        uint256 tokenPerBlock;
        uint256 perShare;
    }
    

    // Info of each pool.
    struct PoolInfo {       
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. MMproes to distribute per block.
        uint256 lastRewardBlock;  // Last block number that MMproes distribution occurs.
        uint256 accMMproPerShare;   // Accumulated MMproes per share, times 1e18. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        uint256 depositLimit;
        uint256 extFarm; 
        IERC20 doubleToken;
        uint256 doublePerBlock;
        uint256 accDoublePerShare;
               
    }

    // The MMpro TOKEN!
    IERC20 public MMpro;
    address public feeAddress;

    // MMpro tokens created per block.
    uint256 public MMproPerBlock = 1 ether;

    // Info of each pool.
    PoolInfo[] public poolInfo;
     // Info of each pool.
    AdditionalPoolInfo[] public additionalPoolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when MMpro mining starts.
    uint256 public startBlock;

    // MMpro referral contract address.
    IReferral public referral;
    // Referral commission rate in basis points.
    uint16 public referralCommissionRate = 500;
    // Max referral commission rate: 10%.
    uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000; 

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetReferralAddress(address indexed user, IReferral indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 MMproPerBlock);
    event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);

    constructor(
        IERC20 _MMpro,
        uint256 _startBlock,
        address _feeAddress
    ) public {
        MMpro = _MMpro;
        startBlock = _startBlock;
        feeAddress = _feeAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }


    mapping(IERC20 => bool) public tokenExistence;
    modifier nonDuplicated(IERC20 _token) {
        require(tokenExistence[_token] == false, "nonDuplicated: duplicated");
        _;
    }

    uint256 private constant _NOT_EXT_FARM = 0;
    uint256 private constant _DOUBLE_FARM = 1;
    uint256 private constant _MULTI_FARM = 2;
    uint256 private constant _MAX_ADDITIONAL_LENGTH = 30;

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, 
    IERC20 _lpToken, 
    uint16 _depositFeeBP,
    uint256 _depositLimit,
    uint256 _extFarm,
    IERC20 _doubleToken,
    uint256 _doublePerBlock
    ) external onlyOwner {
        require(_depositFeeBP <= 1000, "add: invalid deposit fee basis points");
        if(_extFarm == _DOUBLE_FARM){
            require(address(_doubleToken)!=address(0),"zero doubleToken address");
        }
        require(_depositLimit>0,"add: _depositLimit is zero");
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accMMproPerShare: 0,
            depositFeeBP: _depositFeeBP,
            depositLimit: _depositLimit,
            extFarm: _extFarm,
            doubleToken:_doubleToken,
            doublePerBlock:_doublePerBlock,
            accDoublePerShare:0
        }));
    }

    // Update the given pool's MMpro allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, 
    uint16 _depositFeeBP, uint256 _doublePerBlock,uint256 _depositLimit) external onlyOwner {
        require(_depositFeeBP <= 1000, "set: invalid deposit fee basis points");
        PoolInfo storage pool = poolInfo[_pid];
        require(
            _depositLimit>=pool.depositLimit 
            || pool.lpToken.balanceOf(address(this))==0, 
            "set: invalid depositLimit");
        totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(_allocPoint);
        pool.allocPoint = _allocPoint;
        pool.depositFeeBP = _depositFeeBP;
        pool.doublePerBlock = _doublePerBlock;
        pool.depositLimit = _depositLimit;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending MMproes on frontend.
    function pendingMMpro(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMMproPerShare = pool.accMMproPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 MMproReward = multiplier.mul(MMproPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accMMproPerShare = accMMproPerShare.add(MMproReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accMMproPerShare).div(1e18).sub(user.rewardDebt);
    }
    
     function pendingDouble(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDoublePerShare = pool.accDoublePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 DoubleReward = multiplier.mul(pool.doublePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accDoublePerShare = accDoublePerShare.add(DoubleReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accDoublePerShare).div(1e18).sub(user.rewardDoubleDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 MMproReward = multiplier.mul(MMproPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accMMproPerShare = pool.accMMproPerShare.add(MMproReward.mul(1e18).div(lpSupply));
        
        if(pool.extFarm == _DOUBLE_FARM)
        {
            uint256 DoubleReward = multiplier.mul(pool.doublePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accDoublePerShare = pool.accDoublePerShare.add(DoubleReward.mul(1e18).div(lpSupply));
        }
        
        // new functions
        if(pool.extFarm == _MULTI_FARM) {
            uint256 additionPoolsLength = additionalPoolInfo.length;
            for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
            AdditionalPoolInfo storage addPoolItem = additionalPoolInfo[aid];
            uint256 AddtionalReward = multiplier.mul(addPoolItem.tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            addPoolItem.perShare = addPoolItem.perShare.add(AddtionalReward.mul(1e18).div(lpSupply));
         }
        }
        
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for MMpro allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accMMproPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeMMproTransfer(msg.sender, pending);
                payReferralCommission(msg.sender, pending);
            }
            
            if (pool.extFarm == _DOUBLE_FARM) {
                uint256 doubleFarmPending = user.amount.mul(pool.accDoublePerShare).div(1e18).sub(user.rewardDoubleDebt);
                if (doubleFarmPending > 0) {
                    safeTokenTransfer(msg.sender, doubleFarmPending,pool.doubleToken);
                    payReferralCommissionDouble(msg.sender, doubleFarmPending, pool.doubleToken);
                }
            }
            
            if (pool.extFarm == _MULTI_FARM) {
                uint256 additionPoolsLength = additionalPoolInfo.length;
                for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
                    AdditionalPoolInfo storage addPoolItem = additionalPoolInfo[aid];
                    uint256 addPending = user.amount.mul(addPoolItem.perShare).div(1e18).sub(user.multiRewardDebt[address(addPoolItem.token)]);
                    if (addPending > 0) {
                        safeTokenTransfer(msg.sender, addPending,addPoolItem.token);
                        payReferralCommissionDouble(msg.sender, addPending, addPoolItem.token);
                    }
                }
            }
        }
        if (_amount > 0) {
            if (address(referral) != address(0) 
                && _referrer != address(0) 
                && _referrer != msg.sender) {
                    referral.recordReferral(msg.sender, _referrer);
            }
            pool.depositLimit=pool.depositLimit.sub(_amount,
            "the total amount of the deposit for this pool has been exceeded");
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accMMproPerShare).div(1e18);
        user.rewardDoubleDebt = user.amount.mul(pool.accDoublePerShare).div(1e18);
        // multiFarming Debt
        if (pool.extFarm == _MULTI_FARM) {
            uint256 additionPoolsLength = additionalPoolInfo.length;
            for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
            AdditionalPoolInfo storage addPoolItem = additionalPoolInfo[aid];
            user.multiRewardDebt[address(addPoolItem.token)] = user.amount.mul(addPoolItem.perShare).div(1e18);
            }
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accMMproPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            safeMMproTransfer(msg.sender, pending);
            payReferralCommission(msg.sender, pending);
        }
        uint256 doubleFarmPending = user.amount.mul(pool.accDoublePerShare).div(1e18).sub(user.rewardDoubleDebt);
        if (doubleFarmPending > 0) {
            safeTokenTransfer(msg.sender, doubleFarmPending,pool.doubleToken);
            payReferralCommissionDouble(msg.sender, doubleFarmPending, pool.doubleToken);
        }
        if (pool.extFarm == _MULTI_FARM) {
             uint256 additionPoolsLength = additionalPoolInfo.length;
            for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
            AdditionalPoolInfo storage addPoolItem = additionalPoolInfo[aid];
            
            uint256 addPending = user.amount.mul(addPoolItem.perShare).div(1e18).sub(user.multiRewardDebt[address(addPoolItem.token)]);
            if (addPending > 0) {
                safeTokenTransfer(msg.sender,addPending,addPoolItem.token);
                payReferralCommissionDouble(msg.sender, addPending, addPoolItem.token);
            }
         }
            
        }
        if (_amount > 0) {
            pool.depositLimit=pool.depositLimit.add(_amount);
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMMproPerShare).div(1e18);
        user.rewardDoubleDebt = user.amount.mul(pool.accDoublePerShare).div(1e18);
        // multiFarming Debt
        if (pool.extFarm == _MULTI_FARM) {
            uint256 additionPoolsLength = additionalPoolInfo.length;
            for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
            AdditionalPoolInfo storage addPoolItem = additionalPoolInfo[aid];
             user.multiRewardDebt[address(addPoolItem.token)] = user.amount.mul(addPoolItem.perShare).div(1e18);
            }
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardDoubleDebt = 0;
        pool.depositLimit=pool.depositLimit.add(amount);

        if (pool.extFarm == _MULTI_FARM) {
            uint256 additionPoolsLength = additionalPoolInfo.length;
            for (uint256 aid = 0; aid < additionPoolsLength; ++aid) {
             user.multiRewardDebt[address(additionalPoolInfo[aid].token)] = 0;
            }
        }
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe MMpro transfer function, just in case if rounding error causes pool to not have enough .
    function safeMMproTransfer(address _to, uint256 _amount) internal {
        uint256 MMproBal = MMpro.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > MMproBal) {
            transferSuccess = MMpro.transfer(_to, MMproBal);
        } else {
            transferSuccess = MMpro.transfer(_to, _amount);
        }
        require(transferSuccess, "safeMMproTransfer: Transfer failed");
    }

    function safeTokenTransfer(address _to, uint256 _amount,IERC20 _token) internal {
        uint256 balance = _token.balanceOf(address(this));
        if (_amount > balance) {
            _token.safeTransfer(_to, balance);
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function updateEmissionRate(uint256 _MMproPerBlock) external onlyOwner {
        massUpdatePools();
        MMproPerBlock = _MMproPerBlock;
        emit UpdateEmissionRate(msg.sender, _MMproPerBlock);
    }

    // Update the referral contract address by the owner
    function setReferralAddress(IReferral _referral) external onlyOwner {
        referral = _referral;
        emit SetReferralAddress(msg.sender, _referral);
    }

    // Update referral commission rate by the owner
    function setReferralCommissionRate(uint16 _referralCommissionRate) external onlyOwner {
        require(_referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE, "setReferralCommissionRate: invalid referral commission rate basis points");
        referralCommissionRate = _referralCommissionRate;
    }

    // Pay referral commission to the referrer who referred this user.
    function payReferralCommission(address _user, uint256 _pending) internal {
        if (address(referral) != address(0) && referralCommissionRate > 0) {
            address referrer = referral.getReferrer(_user);
            uint256 commissionAmount = _pending.mul(referralCommissionRate).div(10000);

            if (referrer != address(0) && commissionAmount > 0) {
                safeMMproTransfer(referrer, commissionAmount);
                emit ReferralCommissionPaid(_user, referrer, commissionAmount);
            }
        }
    }
    
      // Pay referral commission to the referrer who referred this user in Double Token.
    function payReferralCommissionDouble(address _user, uint256 _pending, IERC20 _token) internal {
        if (address(referral) != address(0) && referralCommissionRate > 0) {
            address referrer = referral.getReferrer(_user);
            uint256 commissionAmount = _pending.mul(referralCommissionRate).div(10000);

            if (referrer != address(0) && commissionAmount > 0) {
                uint256 balance = _token.balanceOf(address(this));
                if (commissionAmount > balance) {
                    _token.safeTransfer(referrer, balance);
                } else {
                    _token.safeTransfer(referrer, commissionAmount);
                }
            }
        }
    }

    // Only update before start of farm
    function updateStartBlock(uint256 _startBlock) public onlyOwner {
        startBlock = _startBlock;
    }
    
    function addMultiFarmToken(IERC20 _token, uint256 _tokenPerBlock) public nonDuplicated(_token) onlyOwner {
        require(additionalPoolInfo.length<=_MAX_ADDITIONAL_LENGTH,"tokens too much");
        additionalPoolInfo.push(AdditionalPoolInfo({
              token: _token,
              tokenPerBlock: _tokenPerBlock,
              perShare: 0
        }));
        tokenExistence[_token] = true;
    }
    
    function setMultiFarm(uint256 _pid, uint256 _tokenPerBlock) public onlyOwner {
         additionalPoolInfo[_pid].tokenPerBlock = _tokenPerBlock;
    }
    
}
