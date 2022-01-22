import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

contract Exchange {
    address public tokenAddress;

    constructor(address _token) {
        require(_token != address(0), "invalid token address");

        tokenAddress = _token;
    }

    function addLiquidity(uint256 _tokenAmount) public payable {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve) 
    public 
    pure 
    returns(uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        return inputReserve * 1000 / outputReserve;
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )  private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        return (inputAmount * outputReserve) / (inputReserve + inputAmount);
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


    //  __minTokens – this is a minimal amount of tokens the user wants to get in exchange for their ethers. This amount is calculated in UI and always includes slippage tolerance; user agrees to get at least that much but not less. This is a very important mechanism that protects users from front-running bots that try to intercept their transactions and modify pool balances to for their profit.
    function ethToTokenSwap(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );
        require(tokensBought>= _minTokens, "insufficient output amount");

        IERC20(tokenAddress).transfer(msg.sender, tokensBought);
    }

    // The function basically transfers _tokensSold of tokens from user’s balance 
    // and sends them ethBought of ethers in exchange.
    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public payable {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEth, "inusffient output amount");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        payable(msg.sender).transfer(ethBought);
    }
}   