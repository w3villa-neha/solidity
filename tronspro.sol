pragma solidity >=0.5.14;

contract TronsPro{
    using SafeMath for uint256;
    uint256 constant MILLION = 100000000;
    uint256 constant minDepositSize = 50000000;  // 50 trx
    uint256 constant TIME = 1;   // 1 days
    uint constant TRX = 1000000;
    
    uint public totalUsers;
    uint public totalInvested;
    uint public totalReinvest;
    uint public activedeposits;
    uint public totalWithdrawn;
    
    address public first;
    address public second;
    address public third;
    
    uint256 public firstInvested;
    uint256 public secondInvested;
    uint256 public thirdInvested;
    
    uint private releaseTime;
    
    address private yieldFarmingWallet;
    address private platformMarkettingWallet;
    address private developerWallet;
    address private insuranceFundWallet;

	uint256 public yieldFarmingAmount;
	uint256 public platformMarkettingAmount;
	
    address owner;
    
    struct Deposit{
        uint256 amount;
        uint256 start;
        uint256 withdrawn;
    }
    
    struct Winners{
        address addr;
        uint256 investedAmount;    
    }
    
    struct User {
        uint256 totalInvestedAmount;
        uint256 totalReinvestedAmount;
        uint256 refReward;
        address referrer;
        Deposit[] deposits;
        uint256 level1Count; 
        uint256 level2Count;
        uint256 level3Count;
        uint256 level4Count;
        bool isExist;
        uint256 launchBonus;
        uint256 reinvestRewardEarned;
        uint256 totalWithdrawn;
    }

    
    uint256[] LevelIncomePercent = [10,3,1,1];
    
    mapping(address => User) public users;
    mapping(uint256 => address) public usersList;
    
    event Newbie(address indexed user, address indexed _referrer, uint _time);  
	event NewDeposit(address indexed user, uint256 amount, uint _time);  
	event Withdrawn(address indexed user, uint256 amount);  
	event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount, uint _time);
	event Reinvest(address indexed user, uint256 amount, uint _time); 
	event withdrawTest(address _user,uint256 _amount,uint256 _lastWithdraw,uint256 _curr,uint256 _diff);
    event ReinvestEvent(address _user,uint256 _amount);
  
    
    constructor(address _yieldFarmingAddr, address _platformMarkettingAddr,address _developerWallet,address _insuranceFundWallet) public {
        developerWallet = _developerWallet;
        yieldFarmingWallet = _yieldFarmingAddr;
        platformMarkettingWallet = _platformMarkettingAddr;
        insuranceFundWallet = _insuranceFundWallet;
		owner = msg.sender;
		releaseTime = block.timestamp;
	}
    
    function invest(address _ref) public payable{
        require(msg.value>=minDepositSize, "must pay min amount");
        _invest(msg.sender,_ref,msg.value);
    }
    
    function _invest(address _user,address _ref,uint256 _amount) internal{
        // call setReferrer
        setReferrer(_user,_ref);
        
        if(users[_user].deposits.length==0){
            users[_user].isExist = true;
            totalUsers = totalUsers.add(1);
            emit Newbie(_user,users[_user].referrer,block.timestamp);
        }
        users[_user].totalInvestedAmount = users[_user].totalInvestedAmount.add(_amount);
        totalInvested = totalInvested.add(_amount);
        
        users[_user].deposits.push(Deposit(_amount,block.timestamp,0));
        emit NewDeposit(_user,_amount,block.timestamp);
        
        // call distributeLevelIncome
        distributeLevelIncome(_user,_amount);
        
        //  give Launching Bonus
        if(checkEligibilityForLaunchingBonus(totalUsers,_amount)){
            address(uint256(_user)).transfer((_amount.mul(2)).div(10));
            users[_user].launchBonus = users[_user].launchBonus.add((_amount.mul(2)).div(10));
        }
        
        // call fundDistribution
        fundDistribution(_amount);
        
        // set daily users
       if(firstInvested<_amount){
           third = second;
           second = first;
           first = msg.sender;
           
           thirdInvested = secondInvested;
           secondInvested = firstInvested;
           firstInvested = _amount;
       }
       else if(secondInvested<_amount){
           third = second;
           second = msg.sender;
           
           thirdInvested = secondInvested;
           secondInvested = _amount;
       }
       
        else if(thirdInvested<_amount){
           third = msg.sender;
            
           thirdInvested = _amount;
        }
            
    }
    
    function setReferrer(address _user,address _ref) internal{
        // referrer should be registered
        // if not registered or invalid address then owner becomes referrer
        if(users[_user].referrer==address(0) && users[_ref].isExist){
            users[_user].referrer = _ref;
        }
        else{
            users[_user].referrer = owner;
        }
        
        if(_user == owner){
            users[_user].referrer = address(0);
        }
    }
    
    function distributeLevelIncome(address _user,uint256 _amount) internal{
        address _ref = users[_user].referrer;
        
        for(uint256 i=1;i<=4;i++){
            if(_ref==address(0))
            break;
            if(i==1){
                users[_ref].level1Count=users[_ref].level1Count.add(1);
                users[_ref].refReward = users[_ref].refReward.add((_amount.mul(LevelIncomePercent[i-1])).div(100));
            }
            if(i==2){
                users[_ref].level2Count=users[_ref].level2Count.add(1);
                users[_ref].refReward = users[_ref].refReward.add((_amount.mul(LevelIncomePercent[i-1])).div(100));
            
            }
            if(i==3){
                users[_ref].level3Count=users[_ref].level3Count.add(1);
                users[_ref].refReward = users[_ref].refReward.add((_amount.mul(LevelIncomePercent[i-1])).div(100));
            
            }
            if(i==4){
                users[_ref].level4Count=users[_ref].level4Count.add(1);
                users[_ref].refReward = users[_ref].refReward.add((_amount.mul(LevelIncomePercent[i-1])).div(100));
            
            }
            _ref = users[_ref].referrer;
        }
    }
    
    function getROI(address _user) public view returns(uint256){
        uint256 percent = getPercent();
      
       uint256 amount;
       uint256 totalAmount;
       
       for(uint256 i=0;i<users[_user].deposits.length;i++){
           if(users[_user].deposits[i].withdrawn<users[_user].deposits[i].amount.mul(3)){
               amount = (users[_user].deposits[i].amount.mul(percent).mul(block.timestamp.sub(users[_user].deposits[i].start))).div(100).div(TIME);
               if(users[_user].deposits[i].withdrawn.add(amount)>=users[_user].deposits[i].amount.mul(3)){
                   amount = users[_user].deposits[i].amount.mul(3).sub(users[_user].deposits[i].withdrawn);
               }
           }
        totalAmount = totalAmount.add(amount);
       }
       
       return totalAmount;
    }
    
    function dailyROICalculation() internal returns(uint256){
       uint256 percent = getPercent();
      
       uint256 amount;
       uint256 totalAmount;
       
       for(uint256 i=0;i<users[msg.sender].deposits.length;i++){
           if(users[msg.sender].deposits[i].withdrawn<users[msg.sender].deposits[i].amount.mul(3)){
               amount = (users[msg.sender].deposits[i].amount.mul(percent).mul(block.timestamp.sub(users[msg.sender].deposits[i].start))).div(100).div(TIME);
               if(users[msg.sender].deposits[i].withdrawn.add(amount)>=users[msg.sender].deposits[i].amount.mul(3)){
                   amount = users[msg.sender].deposits[i].amount.mul(3).sub(users[msg.sender].deposits[i].withdrawn);
               }
               if(amount>0){
                   emit withdrawTest(msg.sender,amount,users[msg.sender].deposits[i].start,block.timestamp,block.timestamp.sub(users[msg.sender].deposits[i].start));
                   users[msg.sender].deposits[i].start = block.timestamp;
                   users[msg.sender].deposits[i].withdrawn = users[msg.sender].deposits[i].withdrawn.add(amount);
               }
           }
        totalAmount = totalAmount.add(amount);
       }
       
       return totalAmount;
    }
    
    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }
    
    function getPercent() public view returns(uint256){
        uint256 contractBalance = address(this).balance;
        uint256 percent;
        if(contractBalance>MILLION.mul(50)){
            percent = 6;
        }
        else if(contractBalance>MILLION.mul(40)){
            percent = 5;
        }
        else if(contractBalance>MILLION.mul(30)){
            percent = 4;
        }
        else if(contractBalance>MILLION.mul(20)){
            percent = 3;
        }
        else if(contractBalance>MILLION.mul(10)){
            percent = 2;
        }
        else{
            percent =1;
        }
        return percent;
    }
   
    function withdrawAll() public{
        // call withdraw for 100% withdrawable amount
        uint256 amount;
        amount = dailyROICalculation();
        address(uint256(platformMarkettingWallet)).transfer(amount.mul(2).div(10));
        
        emit Withdrawn(msg.sender,amount);
        withdraw(msg.sender,amount);
        
    }
    
    function withdraw50Percent() public{
        // min withdrawable amount should be greater than or equal to 100
        // call reinvest for 50% withdrawable amount
        // call withdraw for 50% withdrawable amount
        uint256 amount = dailyROICalculation();
        emit Withdrawn(msg.sender,amount);
        require(amount>=minDepositSize.mul(2), "must have 100 trx for this option");
        withdraw(msg.sender,amount.div(2));
        reinvest(msg.sender,amount.div(2));
    }
    
    function reinvestAll() public{
        // min withdrawable amount should be greater than or equal to 50
        // call reinvest for 100% withdrawable amount
        uint256 amount = dailyROICalculation();
        
        //give reinvest reward
        users[msg.sender].reinvestRewardEarned = users[msg.sender].reinvestRewardEarned.add(amount.mul(2).div(10));
        address(uint256(msg.sender)).transfer(amount.mul(2).div(10));
        
        emit Withdrawn(msg.sender,amount);
        
        require(amount>=minDepositSize, "must have 50 trx for this option");
        reinvest(msg.sender,amount);
    }
    
    function reinvest(address _user,uint256 _amount) internal{
        _invest(_user,users[_user].referrer,_amount);
        users[_user].totalReinvestedAmount = users[_user].totalReinvestedAmount.add(_amount);
        totalReinvest = totalReinvest.add(_amount);
        emit ReinvestEvent(_user,_amount);
    }
    
    function withdraw(address _user,uint256 _amount) internal{
        address(uint256(_user)).transfer(_amount);
        totalWithdrawn = totalWithdrawn.add(_amount);
    }
    
    function fundDistribution(uint256 _amount) internal{
        address(uint256(platformMarkettingWallet)).transfer(_amount.div(10));
        address(uint256(insuranceFundWallet)).transfer(_amount.div(100));
    }
    
    function checkEligibilityForLaunchingBonus(uint256 _id,uint256 _amount) public pure returns(bool){
        // deposited amount should be >=3000 and should be withing 1000 users
        if(_id<=1000 && _amount>=TRX.mul(3000)){
            return true;
        }
        else
        return false;
    }
    
    function getDepositsInfo(address _user,uint256 _index) public view returns(uint256 amount,uint256 start,uint256 withdrawn){
        return (users[_user].deposits[_index].amount,users[_user].deposits[_index].start,users[_user].deposits[_index].withdrawn);
    }
    
    function getActiveDepositsSum(address _user) public view returns(uint256){
        uint256 amount;
        for(uint256 i=0;i<users[_user].deposits.length;i++){
            if(users[_user].deposits[i].withdrawn < users[_user].deposits[i].amount.mul(3)){
                amount = amount.add(users[_user].deposits[i].amount);
            }
        }
        return amount;
    }
    
    function getWinners() public view returns(uint256 first,uint256 second,uint256 third){
        return (first,second,third);
    }
    
    function resetWinners() public{
        first = address(0);
        second = address(0);
        third = address(0);
        
        firstInvested = 0;
        secondInvested = 0;
        thirdInvested = 0;
    }
    
    function distributeDailyReward() public{
        // should be called in between 6 to 6:30 else reward missed
    }
    
}

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

}
