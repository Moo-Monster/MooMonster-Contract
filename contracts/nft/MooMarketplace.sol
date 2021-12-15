// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract MooMarketplace is
  ERC721HolderUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable
{
  using CountersUpgradeable for CountersUpgradeable.Counter;
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  CountersUpgradeable.Counter private _orderIds;

  struct Order {
    address seller;
    address nftAddress;
    uint256 nftId;
    uint256 price;
    bool isActive;
    bool isSold;
    IERC20Upgradeable quoteToken;
    uint256 expireTime;
  }

  // Dont forget to set marketplace attrubutes
  uint256 public constant MAX_FEE = 2000;
  uint256 public constant MIN_PRICE = 1;
  bytes32 public constant OPERATOR_ROLE = keccak256("MOOMONSTER_OPERATOR_ROLE");

  mapping(uint256 => Order) public orders;
  mapping(address => bool) public supportedToken;
  mapping(address => bool) public whitelistNFT;
  address public treasury;
  uint256 public orderExpirePeriod;

  mapping(address => uint256) public tokenFee;

  event OrderCreated(
    address indexed owner,
    address indexed nftAddress,
    uint256 nftId,
    uint256 orderId,
    uint256 price,
    IERC20Upgradeable quoteToken,
    uint256 expireTime
  );
  event OrderSold(
    address indexed buyer,
    address indexed nftAddress,
    uint256 nftId,
    uint256 orderId
  ); // order is bought
  event OrderCancelled(
    address indexed owner,
    address indexed nftAddress,
    uint256 nftId,
    uint256 orderId
  );
  event SetTreasuryAddress(address treasuryAddress);
  event SetWhitelistedNFT(address indexed nftAddress, bool isWhitelisted);
  event SetTokenFee(address indexed tokenAddress, uint256 fee);
  event SetSupportedToken(address indexed tokenAddress, bool isSupported);
  event SetSellingPeriod(uint256 sellingPeriod);

  function initialize(address _treasuryAddress, uint256 _marketplaceFee)
    external
    initializer
  {
    ERC721HolderUpgradeable.__ERC721Holder_init();
    PausableUpgradeable.__Pausable_init();
    AccessControlUpgradeable.__AccessControl_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());

    setTreasuryAddress(_treasuryAddress);
    // Fee for address(0) is default marketplace fee
    setTokenFee(address(0), _marketplaceFee);
  }

  modifier onlySupportedToken(address _tokenAddress) {
    require(supportedToken[_tokenAddress], "MarketPlace: Invalid currency");
    _;
  }

  modifier onlyWhitelistedNFT(address _nftAddress) {
    require(whitelistNFT[_nftAddress], "MarketPlace: Invalid NFT");
    _;
  }

  function pause() external onlyRole(OPERATOR_ROLE) whenNotPaused {
    _pause();
  }

  function unpause() external onlyRole(OPERATOR_ROLE) whenPaused {
    _unpause();
  }

  function setOrderExpirePeriod(uint256 _orderExpirePeriod)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    orderExpirePeriod = _orderExpirePeriod;

    emit SetSellingPeriod(orderExpirePeriod);
  }

  function setTreasuryAddress(address _treasuryAddress)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    treasury = _treasuryAddress;

    emit SetTreasuryAddress(treasury);
  }

  function setSupportedToken(address _tokenAddress, bool _isSupported)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    supportedToken[_tokenAddress] = _isSupported;

    emit SetSupportedToken(_tokenAddress, _isSupported);
  }

  function setTokenFee(address _tokenAddress, uint256 _fee)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(_fee <= MAX_FEE, "MarketPlace: Invalid fee");
    tokenFee[_tokenAddress] = _fee;

    emit SetTokenFee(_tokenAddress, _fee);
  }

  function setWhitelistNFT(address _nftAddress, bool _isWhitelisted)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    whitelistNFT[_nftAddress] = _isWhitelisted;

    emit SetWhitelistedNFT(_nftAddress, _isWhitelisted);
  }

  function createSellingOrder(
    address _nftAddress,
    uint256 _nftId,
    uint256 _price,
    IERC20Upgradeable _quoteToken
  )
    external
    whenNotPaused
    onlySupportedToken(address(_quoteToken))
    onlyWhitelistedNFT(_nftAddress)
  {
    require(_price >= MIN_PRICE, "MarketPlace: Invalid price");

    _orderIds.increment();
    uint256 newOrderId = currentOrderId();
    uint256 orderExpireTime = block.timestamp + orderExpirePeriod;
    orders[newOrderId] = Order({
      seller: _msgSender(),
      nftAddress: _nftAddress,
      nftId: _nftId,
      price: _price,
      isActive: true,
      isSold: false,
      quoteToken: _quoteToken,
      expireTime: orderExpireTime
    });

    _transferNFT(_msgSender(), address(this), _nftAddress, _nftId);

    emit OrderCreated(
      _msgSender(),
      _nftAddress,
      _nftId,
      newOrderId,
      _price,
      _quoteToken,
      orderExpireTime
    );
  }

  function cancelSellingOrder(uint256 _orderId) external whenNotPaused {
    Order memory order = orders[_orderId];

    require(order.seller == _msgSender(), "MarketPlace: Unauthorized");
    require(order.isActive && !order.isSold, "MarketPlace: Invalid order");

    orders[_orderId].isActive = false;
    _transferNFT(address(this), order.seller, order.nftAddress, order.nftId);

    emit OrderCancelled(_msgSender(), order.nftAddress, order.nftId, _orderId);
  }

  function buyNFT(uint256 _orderId) external whenNotPaused {
    require(_exists(_orderId), "MarketPlace: Invalid orderId");

    Order memory sellingOrder = orders[_orderId];

    require(
      block.timestamp < sellingOrder.expireTime,
      "MarketPlace: Order is expired"
    );
    require(
      sellingOrder.isActive && !sellingOrder.isSold,
      "MarketPlace: Invalid order"
    );

    orders[_orderId].isSold = true;
    orders[_orderId].isActive = false;

    uint256 feeRate = tokenFee[address(sellingOrder.quoteToken)];
    if (feeRate == 0) feeRate = tokenFee[address(0)];

    uint256 tradingFee = feeRate.mul(sellingOrder.price).div(10000);

    sellingOrder.quoteToken.safeTransferFrom(
      _msgSender(),
      treasury,
      tradingFee
    );
    sellingOrder.quoteToken.safeTransferFrom(
      _msgSender(),
      sellingOrder.seller,
      sellingOrder.price.sub(tradingFee)
    );

    _transferNFT(
      address(this),
      _msgSender(),
      sellingOrder.nftAddress,
      sellingOrder.nftId
    );

    emit OrderSold(
      _msgSender(),
      sellingOrder.nftAddress,
      sellingOrder.nftId,
      _orderId
    );
  }

  function currentOrderId() public view returns (uint256) {
    return _orderIds.current();
  }

  function _transferNFT(
    address _from,
    address _to,
    address _nftAddress,
    uint256 _nftId
  ) private {
    IERC721Upgradeable(_nftAddress).safeTransferFrom(_from, _to, _nftId);
  }

  function _exists(uint256 _orderId) private view returns (bool) {
    return _orderId <= currentOrderId();
  }
}
