pragma solidity ^0.4.24;
import { IOracle } from "../interfaces/IOracle.sol";

contract TokenA {
	// Public variables of the token
	string public name;
	string public symbol;
	uint8 public decimals = 18;
	IOracle oracleContract;

	/**
	 * Constrctor function
	 *
	 * Initializes contract with initial supply tokens to the creator of the contract
	 */
	constructor(
		string memory tokenName,
		string memory tokenSymbol,
		address oracleAddr
	) public 
	{
		name = tokenName;								   // Set the name for display purposes
		symbol = tokenSymbol;							   // Set the symbol for display purposes
		oracleContract = IOracle(oracleAddr);
	}

	event Transfer(address indexed from, address indexed to, uint tokens);
	event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
	
	function totalSupply() public returns(uint) {
		return oracleContract.totalSupply();
	}
	
	function balanceOf(address addr) public returns(uint balance) {
		return oracleContract.balanceOf(addr);
	}

	function allowance(address user, address spender) public returns(uint value) {
		return oracleContract.allowance(user,spender);
	}

	function transfer(address to, uint value) public returns (bool success) {
		oracleContract.transfer(msg.sender, to, value);
		emit Transfer(msg.sender, to, value);
		return true;
	}

	function transferFrom(address from, address to, uint value) public returns (bool success) {
		oracleContract.transferFrom(msg.sender, from, to, value);
		emit Transfer(from, to, value);
		return true;
	}

	function approve(address spender, uint value) public returns (bool success) {
		oracleContract.approve(msg.sender, spender,  value);
		emit Approval(msg.sender, spender, value);
		return true;
	}
}