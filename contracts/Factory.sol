pragma solidity ^0.8.0;

import "./Exchange.sol";

contract Factory {
    /**
    Factory is a registry so we need a data structure to store exchanges, 
    and that will be a mapping of addresses to addresses – it will allow 
    to find exchanges by their tokens (1 exchange can swap only 1 token, remember?).
     */
    mapping(address => address) public tokenToExchange;

    /**
     
    Next, is the createExchange functions that allows to create and 
    deploy an exchange by simply taking a token address:
    The first ensures the token address is not the zero address (0x0000000000000000000000000000000000000000).
    Next one ensures that the token hasn’t already been added to the registry (default address value is the zero address). 
    The idea is that we don’t want to have different exchanges for the same token because 
    we don’t want liquidity to be scattered across multiple exchanges. It should better 
    be concentrated on one exchange to reduce slippage and provide better exchange rates.
    */
    function createExchange(address _tokenAddress) public returns (address) {
        require(_tokenAddress != address(0), "invalid token address");
        require(
            tokenToExchange[_tokenAddress] == address(0),
            "exchange already exists"
        );

        Exchange exchange = new Exchange(_tokenAddress);
        tokenToExchange[_tokenAddress] = address(exchange);

        return address(exchange);
    }

    /**
    To finish the contract, we need to implement only one more function – getExchange, which will 
    allow us to query the registry via an interface from another contract:
     */
    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress];
    }

}