// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

/**
 * @title Mock USDT
 * @author Aave Labs
 * @notice Mock for USDT that has non-standard behavior (in contrast to ERC-20) for transfer and approval functions
 */
contract MockUSDT {

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    //////////////////////// USDT NON-STANDARD FUNCTIONS ////////////////////////

    /**
     * @dev Does not return boolean in purpose. As it does not follow the ERC-20 standard properly.
     */
    function transfer(address to, uint256 amount) public virtual {
        address owner = msg.sender;
        _transfer(owner, to, amount);
    }

    /**
     * @dev Does not return boolean in purpose. As it does not follow the ERC-20 standard properly.
     * Also, the additional requirement to not allow approval if was not previously set to 0.
     */
    function approve(address spender, uint256 amount) public virtual {
        address owner = msg.sender;
        require(!((amount != 0) && (_allowances[owner][spender] != 0)));
        _approve(owner, spender, amount);
    }

    /**
     * @dev Does not return boolean in purpose. As it does not follow the ERC-20 standard properly.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
    }

    //////////////////////////// MOCK FUNCTIONS ////////////////////////////


    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    ////////////////////// ERC-20 STANDARD FUNCTIONS //////////////////////

    function name() public view virtual returns (string memory) {
        return "Mock USDT";
    }

    function symbol() public view virtual returns (string memory) {
        return "mUSDT";
    }

    function decimals() public view virtual returns (uint8) {
        return 6;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit IERC20.Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit IERC20.Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit IERC20.Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit IERC20.Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
