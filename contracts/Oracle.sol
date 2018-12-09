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
		uint committedAt;
	}

	struct DelegateStake{
		address addr;
		uint timeInSecond;
		uint stake;
		uint8 v;
		bytes32 r;
		bytes32 s;
	}
	uint public inceptionTimeInSecond;
	uint public inceptionPriceInWei;
	uint public period;
	uint public mingRatio = 1;
	uint public openWindowTimeInSecond;

	uint public lastPriceTimeInSecond;
	uint public lastPrice;

	// 
	mapping(address => uint) public balanceOf;
	mapping(address => mapping (address => uint)) public allowance;
	mapping(address => uint) public userStakedAmtInWei; // for every one


	// uint public totalVotersForCurrentRound;

	// voters
	address[] votersInCurrentRound;
	mapping(address => bool) hasVotedInCurrentRound;
	mapping(address => uint) public votedStateInCurrentRound; //voter => votes

	// uint public totalFeeders;
	// committers
	mapping (address => bool) public isWhiteListCommitter;
	address[] committerList;
	address[] commiitersInCurrentRound;
	mapping(address => Price) public committedPriceInCurrentRound;

	uint[] priceDiffInCurrentRound;
	uint[] sortedPriceDiffArray;
	address[] winnersInCurrentRound;
	mapping(address => uint) committerPriceDiffInCurrentRound;
	// mapping(uint => address) deltaPriceToAddr;
	
	mapping(address => bool) public hasCommittedInCurrentRound;
	mapping(address => uint) public receivedVotesInCurrentRound; 
	
	//committer => votesReciverd
	// address[] addressCommitted;
	// uint[] addressDelta;

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
		require(isWhiteListCommitter[msg.sender] == true);
		_;
	}

	/*
     * Events
     */
	event Transfer(address indexed from, address indexed to, uint value);
	event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
	event CommitPrice(uint indexed priceInWei, uint indexed timeInSecond, address sender);
	event Inception(uint inceptionTime, uint inceptionPriceInWei, address startAddr);
	event AcceptPrice(uint priceInWei, uint timeInSecond, address winner);

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
		address sender = msg.sender;
		period = pd;
		openWindowTimeInSecond = openWindow;
		isWhiteListCommitter[sender] = true;
		name = tokenName;								   // Set the name for display purposes
		symbol = tokenSymbol;							   // Set the symbol for display purposes
		totalSupply = totalSupplyInWei;
		balanceOf[sender] = totalSupplyInWei;
		committerList.push(sender);
	}

	/*
     * Public Functions
     */
	function startOracle(
		uint startTime,
		uint startPrice,
		address[] memory whiteList
	)
		public 
		isPriceFeed() 
		returns (bool success) 
	{
		inceptionTimeInSecond = startTime;
		inceptionPriceInWei = startPrice;
		lastPriceTimeInSecond = startTime;
		for(uint i = 0;  i < whiteList.length; i++ ) {
			if(!isWhiteListCommitter[whiteList[i]]){
				isWhiteListCommitter[whiteList[i]] = true;
				committerList.push(whiteList[i]);
			}
		}
		emit Inception(startTime, startPrice, msg.sender);
		return true;
	}

	function stake(uint amtInWei) public returns(bool){
		address sender = msg.sender;
		require(amtInWei <= balanceOf[sender]);
		balanceOf[sender] = balanceOf[sender] - amtInWei;
		userStakedAmtInWei[sender] = userStakedAmtInWei[sender] + amtInWei;
		return true;
	}

	function unStake(uint amtInWei) public returns(bool){
		address sender = msg.sender;
		require(amtInWei <= userStakedAmtInWei[sender]);
		balanceOf[sender] = balanceOf[sender] + amtInWei;
		userStakedAmtInWei[sender] = userStakedAmtInWei[sender] - amtInWei;
		return true;
	}

	function commitPrice(
		uint priceInWei, 
		uint timeInSecond, 
		address[] voterAddrs, 
		uint[2][] timeStakeOfVoters, 
		uint8[] vList, 
		bytes32[2][] rsList
	) 
		public 
		isPriceFeed()
		returns (bool success)
	{	
		require(!hasCommittedInCurrentRound[msg.sender]);
		if(
			lastPriceTimeInSecond.add(period).add(openWindowTimeInSecond) >= timeInSecond
			&& lastPriceTimeInSecond.add(period).sub(openWindowTimeInSecond) <= timeInSecond
		)
		{
			// within commit window
			committedPriceInCurrentRound[msg.sender] = Price(priceInWei, timeInSecond, block.timestamp);
			hasCommittedInCurrentRound[msg.sender] = true;
			commiitersInCurrentRound.push(msg.sender);

			for(uint i = 0; i<voterAddrs.length; i++){
				if(
					timeStakeOfVoters[0][i]== timeInSecond &&
					votedStateInCurrentRound[voterAddrs[i]] <= userStakedAmtInWei[voterAddrs[i]] &&
					verify(
						voterAddrs[i], 
						keccak256(abi.encodePacked( 
							concat(
								bytes32ToString(bytes32(timeStakeOfVoters[0][i])),
								bytes32ToString(bytes32(timeStakeOfVoters[1][i]))
							)
						)),
						vList[i],
						rsList[0][i],
						rsList[1][i]
					)
				){
					votedStateInCurrentRound[voterAddrs[i]] = votedStateInCurrentRound[voterAddrs[i]].add(timeStakeOfVoters[1][i]);
					if(!hasVotedInCurrentRound[voterAddrs[i]]) {
						hasVotedInCurrentRound[voterAddrs[i]] = true;
						votersInCurrentRound.push(voterAddrs[i]);
					}
					receivedVotesInCurrentRound[msg.sender] = receivedVotesInCurrentRound[msg.sender].add(timeStakeOfVoters[1][i]);
				}
			}

			return true;	
		} else if (lastPriceTimeInSecond.add(period).add(openWindowTimeInSecond) < block.timestamp ){
			// round end, settle
			return terminateRound();
		}
		return true;
	}

	function terminateRound() internal returns(bool) {
		lastPrice = calcFinalPrice();
		
		for(uint j = 0;j < commiitersInCurrentRound.length; j++) {
			address committer = commiitersInCurrentRound[j];
			uint price = committedPriceInCurrentRound[committer].priceInWei;
			uint priceDiff = (price >= lastPrice)? (price - lastPrice): (lastPrice - price);
			priceDiffInCurrentRound.push(priceDiff);
			committerPriceDiffInCurrentRound[committer] = priceDiff;
		}

		sortedPriceDiffArray = sort(priceDiffInCurrentRound);
		
		for(uint k = 0; k< commiitersInCurrentRound.length; k++){
			if(committerPriceDiffInCurrentRound[commiitersInCurrentRound[k]] == sortedPriceDiffArray[0]){
				winnersInCurrentRound.push(commiitersInCurrentRound[k]);
			}
		}
		for(uint m = 0; m< winnersInCurrentRound.length; m++){
			balanceOf[winnersInCurrentRound[m]] = balanceOf[winnersInCurrentRound[m]].add(totalSupply * mingRatio / BP_DENOMINATOR / winnersInCurrentRound.length);
		}

		startNextRound();
		return false;

	}

	function startNextRound() internal {
		lastPriceTimeInSecond = lastPriceTimeInSecond.add(period);
		for(uint i = 0; i< votersInCurrentRound.length; i++){
			address voter = votersInCurrentRound[i];
			hasVotedInCurrentRound[voter] = false;
			votedStateInCurrentRound[voter] = 0;
		}

		for(uint j = 0; j<commiitersInCurrentRound.length; j++ ){
			address committer = commiitersInCurrentRound[j];
			committerPriceDiffInCurrentRound[committer] = 0;
			hasCommittedInCurrentRound[committer] = false;
			receivedVotesInCurrentRound[committer] = 0;

		}
		delete votersInCurrentRound;
		delete commiitersInCurrentRound;
		delete priceDiffInCurrentRound;
		delete sortedPriceDiffArray;
		delete winnersInCurrentRound;
	}

	function calcFinalPrice() view internal returns (uint)  {
		uint currentTime = lastPriceTimeInSecond + period;
		uint weightedPricesSum = 0;
		uint weightsSum = 0;
		for(uint i = 0; i<commiitersInCurrentRound.length; i++)
		{
			address committer = commiitersInCurrentRound[i];
			uint priceInWei = committedPriceInCurrentRound[committer].priceInWei;
			uint committedAt = committedPriceInCurrentRound[committer].committedAt;
			uint totalStakeAmt = userStakedAmtInWei[committer].add(receivedVotesInCurrentRound[committer]);
			uint deltaTime = (committedAt >= currentTime)? (committedAt - currentTime + 1): (currentTime - committedAt + 1);
			uint weight = totalStakeAmt/deltaTime; //wanghe need to convert to wei?
			weightedPricesSum = weightedPricesSum.add(weight * priceInWei);
			weightsSum = weightsSum.add(weight);
		}
		uint finalPriceInWei = weightedPricesSum / weightsSum; // wanghe need to convert to wei?
		return finalPriceInWei;
	}

	// start of utils
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

	function verify(address addr, bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns(bool) {
        return ecrecover(hash, v, r, s) == addr;
    }
	// end of utils

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
