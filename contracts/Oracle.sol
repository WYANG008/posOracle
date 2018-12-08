pragma solidity ^0.5.1;
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
		address source;
	}
	bool public open = false;

	/*
     * Modifier
     */
	modifier isPriceFeed() {
		require(msg.sender == priceFeed1 || msg.sender == priceFeed2 || msg.sender == priceFeed3);
		_;
	}

	/*
     * Events
     */
	event CommitPrice(uint indexed priceInWei, uint indexed timeInSecond, address sender, uint index);
	event AcceptPrice(uint indexed priceInWei, uint indexed timeInSecond, address sender);
	event SetValue(uint index, uint oldValue, uint newValue);
	event UpdatePriceFeed(address updater, address newPriceFeed);

	/*
     * Constructor
     */
	constructor(
		address opt,
		address pf1,
		address pf2,
		address pf3,
		address roleManagerAddr,
		uint pxCoolDown,
		uint optCoolDown
		) 
		public
	{
		priceFeed1 = pf1;
		priceFeed2 = pf2;
		priceFeed3 = pf3;
		priceUpdateCoolDown = pxCoolDown;
		roleManagerAddress = roleManagerAddr;
		roleManager = IMultiSigManager(roleManagerAddr);
		emit UpdateRoleManager(roleManagerAddress);
	}


	/*
     * Public Functions
     */
	function startOracle(
		uint priceInWei, 
		uint timeInSecond
	)
		public 
		isPriceFeed() 
		returns (bool success) 
	{
		require(!started && timeInSecond <= getNowTimestamp());
		lastPrice.timeInSecond = timeInSecond;
		lastPrice.priceInWei = priceInWei;
		lastPrice.source = msg.sender;
		started = true;
		emit AcceptPrice(priceInWei, timeInSecond, msg.sender);
		return true;
	}


	function getLastPrice() public view returns(uint, uint) {
		return (lastPrice.priceInWei, lastPrice.timeInSecond);
	}

	// start of oracle
	function commitPrice(uint priceInWei, uint timeInSecond) 
		public 
		isPriceFeed()
		returns (bool success)
	{	

		return true;
	}

	/*Internal Functions
     */
	function acceptPrice(uint priceInWei, uint timeInSecond, address source) internal {
		emit AcceptPrice(priceInWei, timeInSecond, source);
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

}
