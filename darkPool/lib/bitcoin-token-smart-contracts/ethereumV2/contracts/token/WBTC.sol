pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/StandardToken.sol";
import "@openzeppelin/contracts/token/ERC20/DetailedERC20.sol";
import "@openzeppelin/contracts/token/ERC20/MintableToken.sol";
import "@openzeppelin/contracts/token/ERC20/BurnableToken.sol";
import "@openzeppelin/contracts/token/ERC20/PausableToken.sol";
import "../token/WrappedToken.sol";

contract WBTC is WrappedToken, DetailedERC20("Wrapped BTC", "WBTC", 8) {}
