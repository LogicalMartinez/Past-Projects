pragma solidity ^0.8.18;

import "openzeppelin/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin/contracts/token/ERC20/DetailedERC20.sol";
import "openzeppelin/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin/contracts/token/ERC20/BurnableToken.sol";
import "openzeppelin/contracts/token/ERC20/PausableToken.sol";
import "../utils/OwnableContract.sol";

contract WrappedToken is
    StandardToken,
    MintableToken,
    BurnableToken,
    PausableToken,
    OwnableContract
{
    function burn(uint value) public onlyOwner {
        super.burn(value);
    }

    function finishMinting() public onlyOwner returns (bool) {
        return false;
    }

    function renounceOwnership() public onlyOwner {
        revert("renouncing ownership is blocked");
    }
}
