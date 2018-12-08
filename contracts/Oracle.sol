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
	}

	struct DelegateStake{
		address addr;
		uint timeInSecond;
		uint stakes;
		uint8 v;
		bytes32 r;
		bytes32 s;
	}
	bool public open = false;
	address public tokenAddress;
	uint public period;
	uint public openWindowTimeInSecond;
	uint public lastPriceTimeInSecond;
	uint public inceptionTimeInSecond;
	mapping (address => uint) public whiteListFeeders;
	mapping(address => uint) public balanceOf;
	mapping (address => mapping (address => uint)) public allowance;
	mapping (address => uint) public stakeAmts;
	mapping (address => uint) public stakedAmt;
	mapping (address => uint) public stakeForCurrentRound;
	mapping (address => Price) public stakedPrice;

	/*
     * Modifier
     */
	modifier isPriceFeed() {
		require(whiteListFeeders[msg.sender] == 1);
		_;
	}

	modifier isOpenForCommit(uint timeInSecond) {
		uint blkTime = block.timestamp;
		require(lastPriceTimeInSecond.add(period).add(openWindowTimeInSecond) >= blkTime 
		&& lastPriceTimeInSecond.add(period).sub(openWindowTimeInSecond) <= blkTime);
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
		uint openWindow
		) 
		public
	{
		period = pd;
		openWindowTimeInSecond = openWindow;
		whiteListFeeders[msg.sender] = 1;
	}


	/*
     * Public Functions
     */
	function startOracle(
		uint startTime,
		address tokenAddr,
		address[] memory whiteList
	)
		public 
		isPriceFeed() 
		returns (bool success) 
	{
		inceptionTimeInSecond = startTime;
		tokenAddress = tokenAddr;
		for(uint i = 0;  i < whiteList.length; i++ ) {
			whiteListFeeders[whiteList[i]] = 1;
		}
		emit Inception(inceptionTimeInSecond, msg.sender);
		return true;
	}

	

	function verify(address addr, bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns(bool) {
        return ecrecover(hash, v, r, s) == addr;
    }

	// start of oracle
	function commitPrice(uint priceInWei, uint timeInSecond, DelegateStake[] memory delegatedStakes) 
		public 
		isPriceFeed()
		isOpenForCommit(timeInSecond) 
		returns (bool success)
	{	

		stakedPrice[msg.sender] = Price(priceInWei,timeInSecond);

		for(uint i = 0; i<delegatedStakes.length; i++){
			DelegateStake memory stake = delegatedStakes[i];
			if(
				stake.timeInSecond == timeInSecond &&
				stake.stakes.add(stakedAmt[stake.addr]) <= stakeAmts[stake.addr] &&
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
			)){
				stakeForCurrentRound[msg.sender] = stakeForCurrentRound[msg.sender].add(stake.stakes);
				stakedAmt[stake.addr] = stakedAmt[stake.addr].add(stake.stakes);
			}
		}

		return true;
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

	function getMedian(uint a, uint b, uint c) internal pure returns (uint) {
		if (a.gt(b) ^ c.gt(a) == 0x0) {
			return a;
		} else if(b.gt(a) ^ c.gt(b) == 0x0) {
			return b;
		} else {
			return c;
		}
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

	function determineAddress(address from) internal view returns (address) {
		return 
			msg.sender == tokenAddress? from : msg.sender;
	}

	function transfer(address from, address to, uint tokens)
		public
		returns (bool success) 
	{
		return transferInternal( determineAddress(from), to, tokens);
	}

	function transferFrom( address spender, address from, address to, uint tokens) 
		public 
		returns (bool success) 
	{
		address spenderToUse = determineAddress( spender);
		require(tokens <= allowance[from][spenderToUse]);	 // Check allowance
		allowance[from][spenderToUse] = allowance[from][spenderToUse].sub(tokens);
		return transferInternal( from, to, tokens);
	}

	function approve(address sender, address spender, uint tokens) 
		public 
		returns (bool success) 
	{
		address senderToUse = determineAddress( sender);
		allowance[senderToUse][spender] = tokens;
		emit Approval(senderToUse, spender, tokens);
		return true;
	}

}
