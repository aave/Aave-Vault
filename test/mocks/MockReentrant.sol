// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract MockReentrant {
    address _target;
    bytes _data;
    uint256 _msgValue;
    uint256 _times;

    function configureReentrancy(address target, bytes memory data, uint256 msgValue, uint256 times) public {
        _target = target;
        _data = data;
        _msgValue = msgValue;
        _times = times;
    }

    fallback() external payable {
        if (_times > 0) {
            _times--;
            _target.call{value: _msgValue}(_data);
        }
    }

    receive() external payable {
        if (_times > 0) {
            _times--;
            _target.call{value: _msgValue}(_data);
        }
    }
}
