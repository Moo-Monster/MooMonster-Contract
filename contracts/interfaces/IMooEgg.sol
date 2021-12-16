// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IMooEgg {
  function currentTokenId() external view returns (uint256);

  function mint(address _to) external;
}
