pragma solidity ^0.4.24;

interface IOracle {
	function totalUsers() external returns (uint);
	function totalSupply() external returns (uint);
	function balanceOf(address) external returns (uint);
	function allowance( address, address) external returns (uint);
	function transfer(address, address, uint) external returns (bool);
	function transferFrom(address, address, address, uint) external returns (bool);
	function approve(address, address, uint) external returns (bool);
}