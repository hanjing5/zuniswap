pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange is ERC20 {
    address public tokenAddress; 
    address public factoryAddress; // https://jeiwan.net/posts/programming-defi-uniswap-3/

    constructor(address _token) ERC20 ("Zuniswap-V1", "ZUNI-V1") {
        require(_token != address(0), "invalid token address");

        tokenAddress = _token;
        factoryAddress = msg.token; // https://jeiwan.net/posts/programming-defi-uniswap-3/
    }

    // if reserve is 0, allow any liquidity to be added
    // if reserve is not 0, enforce proportion
    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256){

        // initial creation of liquidity pool
        // https://jeiwan.net/posts/programming-defi-uniswap-2/
        if (getReserve() == 0) {
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);   

            // when adding initial liquidity, the amount of LP-tokens issued 
            // equals to the amount of ethers deposited.
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
            return liquidity; 
        } else {
            // https://jeiwan.net/posts/programming-defi-uniswap-2
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = msg.value * (tokenReserve / ethReserve);
            // given a fixed amount of ETH (msg.value), we want as much token as 
            // the user is willing to part with
            require(_tokenAmount >= tokenAmount, "insufficient token amount"); 

            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);

            // Additional liquidity mints LP-tokens proportionally to the amount of ethers deposited:
            uint256 liqudity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
            return liquidity;
            
        }
    }

    /**
    we can again use LP-tokens: we don’t need to remember amounts deposited by each liquidity provider 
    and can calculate the amount of removed liquidity based on an LP-tokens share.

    When liquidity is removed, it’s returned in both ethers and tokens and their amounts are, of course, balanced.
    This is the moment that causes impermanent loss: the ratio of reserves changes over time following changes in 
    their prices in USD. When liquidity is removed the balance can be different from what it was when liquidity was 
    deposited. This means that you would get different amounts of ethers and tokens and their total price might be 
    lower than if you have just held them in a wallet.

    To calculate the amounts we multiply reserves by the share of LP-tokens:

    Notice that LP-tokens are burnt each time liquidity is removed. LP-tokens are only backed by deposited liquidity.
    // https://jeiwan.net/posts/programming-defi-uniswap-2
     */
    function removeLiquidity(uint _amount) public returns (uint256, uint256) {
        require(_amount > 0, "invalid amount");

        uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
        uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve)
        public
        pure
        returns (uint256)
    {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        return (inputReserve * 1000) / outputReserve;
    }
    
    // We’ll take 1% just so that it’s easier to see the difference in tests. 
    // Adding fees to the contract is as easy as adding a couple of multipliers 
    // to getAmount function:
    // https://jeiwan.net/posts/programming-defi-uniswap-2/
    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
    
        return numerator / denominator;
    }

    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ethSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");

        IERC20(tokenAddress).transfer(msg.sender, tokensBought);
    }

    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEth, "insufficient output amount");

        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        payable(msg.sender).transfer(ethBought);
    }
}
