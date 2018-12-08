pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import { SafeMath } from "./common/SafeMath.sol";

/// @title Oracle
/// @author 
contract Oracle {
	using SafeMath for uint;

	/*
     * Storage
     */
	struct Price {
		uint priceInWei;
		uint timeInSecond;
		uint blockTime;
	}

	struct DelegateStake{
		address addr;
		uint timeInSecond;
		uint stakes;
		uint8 v;
		bytes32 r;
		bytes32 s;
	}
	uint public period;
	uint public mingRatio = 1;
	uint public openWindowTimeInSecond;
	uint public lastPriceTimeInSecond;
	uint public inceptionTimeInSecond;
	
	mapping(address => uint) public balanceOf;
	mapping (address => mapping (address => uint)) public allowance;
	mapping (address => uint) public totalStakedAmt; // for every one
	uint skipNum = 0;


	uint public totalVotersForCurrentRound;
	address[] votersInCurrentRound;
	mapping(address => bool) hasVotedInCurrentRound;
	mapping(address => uint) public votesForCurrentRound; //voter => votes

	uint public totalFeeders;
	address[] feederLists;
	mapping (address => Price) public committedPrice;
	mapping(uint => address) deltaPriceToAddr;
	mapping (address => bool) public isWhiteListFeeders;
	mapping(address => bool) public hasCommitted;
	mapping(address => uint) public receivedVotes; //committer => votesReciverd
	address[] addressCommitted;
	uint[] addressDelta;

	uint constant WEI_DEOMINATOR = 1000000000000000000;
	uint constant BP_DENOMINATOR = 10000;

	string public name;
	string public symbol;
	uint public totalSupply;
	uint8 public decimals = 18;



	/*
     * Modifier
     */
	modifier isPriceFeed() {
		require(isWhiteListFeeders[msg.sender] == true);
		_;
	}

	/*
     * Events
     */
	event Transfer(address indexed from, address indexed to, uint value);
	event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
	event CommitPrice(uint indexed priceInWei, uint indexed timeInSecond, address sender);
	event Inception(uint inceptionTime, address startAddr);

	/*
     * Constructor
     */
	constructor(
		uint pd,
		uint openWindow,
		string memory tokenName,
		string memory tokenSymbol,
		uint totalSupplyInWei
		) 
		public
	{
		period = pd;
		openWindowTimeInSecond = openWindow;
		isWhiteListFeeders[msg.sender] = true;
		name = tokenName;								   // Set the name for display purposes
		symbol = tokenSymbol;							   // Set the symbol for display purposes
		totalSupply = totalSupplyInWei;
		balanceOf[msg.sender] = totalSupplyInWei;
	}

	/*
     * Public Functions
     */
	function startOracle(
		uint startTime,
		address[] memory whiteList
	)
		public 
		isPriceFeed() 
		returns (bool success) 
	{
		inceptionTimeInSecond = startTime;
		lastPriceTimeInSecond = startTime;
		for(uint i = 0;  i < whiteList.length; i++ ) {
			isWhiteListFeeders[whiteList[i]] = true;
			feederLists.push(whiteList[i]);
			totalFeeders +=1;
		}
		emit Inception(inceptionTimeInSecond, msg.sender);
		return true;
	}

	function stake(uint amtInWei) public {
		address sender = msg.sender;
		require(amtInWei <= balanceOf[sender]);
		
		balanceOf[sender] = balanceOf[sender] - amtInWei;
		totalStakedAmt[sender] = totalStakedAmt[sender] + amtInWei;
	}

	function unStake(uint amtInWei) public {
		address sender = msg.sender;
		require(amtInWei <= totalStakedAmt[sender]);
		balanceOf[sender] = balanceOf[sender] + amtInWei;
		totalStakedAmt[sender] = totalStakedAmt[sender] - amtInWei;
	}

	function verify(address addr, bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns(bool) {
        return ecrecover(hash, v, r, s) == addr;
    }

// start of oracle
	function commitPrice(uint priceInWei, uint timeInSecond, DelegateStake[] memory delegatedStakes) 
		public 
		isPriceFeed()
		returns (bool success)
	{	
		address sender = msg.sender;
		uint blkTime = block.timestamp;

		if(
			lastPriceTimeInSecond.add(period).add(openWindowTimeInSecond) >= blkTime 
			&& lastPriceTimeInSecond.add(period).sub(openWindowTimeInSecond) <= blkTime
		)
		{
			committedPrice[sender] = Price( priceInWei,timeInSecond,block.timestamp);
			addressCommitted.push(sender);
			hasCommitted[sender] = true;

			for(uint i = 0; i<delegatedStakes.length; i++){
				DelegateStake memory stake = delegatedStakes[i];
				if(
					stake.timeInSecond == timeInSecond &&
					votesForCurrentRound[stake.addr] <= totalStakedAmt[stake.addr] &&
					verify(
						stake.addr, 
						keccak256(abi.encodePacked( 
							concat(
								bytes32ToString(bytes32(stake.timeInSecond)),
								bytes32ToString(bytes32(stake.stakes))
							)
						)),
						stake.v,
						stake.r,
						stake.s				
					)
				){
					votesForCurrentRound[stake.addr] = votesForCurrentRound[stake.addr].add(stake.stakes);
					if(!hasVotedInCurrentRound[stake.addr]) {
						totalVotersForCurrentRound+=1;
						hasVotedInCurrentRound[stake.addr] = true;
						votersInCurrentRound[totalVotersForCurrentRound] = stake.addr;
					}
					
					receivedVotes[sender] = receivedVotes[sender].add(stake.stakes);
				}
			}

			return true;	
		} else if (lastPriceTimeInSecond.add(period).add(openWindowTimeInSecond) < blkTime ){
			// round end, settle
			
			uint finalPriceInWei = calcFinalPrice();
			// uint size = addressCommitted.length;
			
			// uint[] storage prices = [];
			for(uint j = 0;j <addressCommitted.length; j++){
				address addr = addressCommitted[i];
				uint price = committedPrice[addr].priceInWei;
				uint delta = (price >= finalPriceInWei)? (price - finalPriceInWei): (finalPriceInWei - price);
				addressDelta.push(delta);
				deltaPriceToAddr[delta] = addr;
			}

			uint[] memory sortedDeltaArray = sort(addressDelta);
			balanceOf[deltaPriceToAddr[sortedDeltaArray[0]]] = 
				balanceOf[deltaPriceToAddr[sortedDeltaArray[0]]]
				.add(totalSupply * mingRatio / BP_DENOMINATOR);

			
			startNextRound();

		}
	}

	function startNextRound() {
		lastPriceTimeInSecond = lastPriceTimeInSecond.add(period);
		for(uint i = 0;i <totalVotersForCurrentRound; i ++) {
			hasVotedInCurrentRound[votersInCurrentRound[i]] = false;
			votesForCurrentRound[votersInCurrentRound[i]] = 0;
			votersInCurrentRound[i]=address(0);
		}

		for(uint j = 0; j< totalFeeders; j++){
			hasCommitted[feederLists[j]] = false;
			receivedVotes[feederLists[j]] = 0;


		}
	}

	function calcFinalPrice() view internal returns (uint)  {
		uint currentTime = lastPriceTimeInSecond + period;
		uint weightedPricesSum = 0;
		uint weightsSum = 0;
		// mapping(address => uint) deltaT;
		for(uint i = 0; i<addressCommitted.length; i++)
		{
			address addr = addressCommitted[i];
			uint priceInWei = committedPrice[addr].priceInWei;
			uint blockTime = committedPrice[addr].blockTime;
			uint stakeAmt = totalStakedAmt[addr];
			uint deltaTime = (blockTime >= currentTime)? (blockTime - currentTime): (currentTime - blockTime);
			uint weight = stakeAmt.add(receivedVotes[addr])/deltaTime; //wanghe need to convert to wei?
			weightedPricesSum = weightedPricesSum.add(weight * priceInWei);
			weightsSum = weightsSum.add(weight);
		}

		uint finalPrice = weightedPricesSum / weightsSum; // wanghe need to convert to wei?
		return finalPrice;
	}


	function bytes32ToString(bytes32 x) internal pure returns (string) {
		bytes memory bytesString = new bytes(32);
		uint charCount = 0;
		for (uint j = 0; j < 32; j++) {
			byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
			if (char != 0) {
				bytesString[charCount] = char;
				charCount++;
			}
		}
		bytes memory bytesStringTrimmed = new bytes(charCount);
		for (j = 0; j < charCount; j++) {
			bytesStringTrimmed[j] = bytesString[j];
		}
		return string(bytesStringTrimmed);
	}

	
	// end of oracle

	function concat(string memory _a, string memory  _b) public pure returns (string){
        bytes memory bytes_a = bytes(_a);
        bytes memory bytes_b = bytes(_b);
        string memory length_ab = new string(bytes_a.length + bytes_b.length);
        bytes memory bytes_c = bytes(length_ab);
        uint k = 0;
        for (uint i = 0; i < bytes_a.length; i++) bytes_c[k++] = bytes_a[i];
        for (i = 0; i < bytes_b.length; i++) bytes_c[k++] = bytes_b[i];
        return string(bytes_c);
    }

	function sort(uint[] data) public returns(uint[]) {
       quickSort(data, int(0), int(data.length - 1));
       return data;
    }
    
    function quickSort(uint[] memory arr, int left, int right) internal{
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

	/*
     * ERC token functions
     */
	/// @dev transferInternal function.
	/// @param from  from address
	/// @param to   to address
	/// @param tokens num of tokens transferred
	function transferInternal(address from, address to, uint tokens) 
		internal 
		returns (bool success) 
	{
		// Prevent transfer to 0x0 address. Use burn() instead
		require(to != address(0));
		// Check if the sender has enough
		require(balanceOf[from] >= tokens);
		// Save this for an assertion in the future
		uint previousBalances = balanceOf[from].add(balanceOf[to]);
		// Subtract from the sender
		balanceOf[from] = balanceOf[from].sub(tokens);
		// Add the same to the recipient
		balanceOf[to] = balanceOf[to].add(tokens);
		// Asserts are used to use static analysis to find bugs in your code. They should never fail
		assert(balanceOf[from].add(balanceOf[to]) == previousBalances);
		emit Transfer(from, to, tokens);
		return true;
	}

	function transfer(address to, uint tokens)
		public
		returns (bool success) 
	{
		return transferInternal( msg.sender, to, tokens);
	}

	function transferFrom( address from, address to, uint tokens) 
		public 
		returns (bool success) 
	{
		address spenderToUse = msg.sender;
		require(tokens <= allowance[from][spenderToUse]);	 // Check allowance
		allowance[from][spenderToUse] = allowance[from][spenderToUse].sub(tokens);
		return transferInternal( from, to, tokens);
	}

	function approve( address spender, uint tokens) 
		public 
		returns (bool success) 
	{
		address senderToUse = msg.sender;
		allowance[senderToUse][spender] = tokens;
		emit Approval(senderToUse, spender, tokens);
		return true;
	}

}
