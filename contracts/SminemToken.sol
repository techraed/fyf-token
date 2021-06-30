pragma solidity 0.5.7;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-solidity/contracts/GSN/Context.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
//import "../node_modules/openzeppelin-solidity/contracts/utils/Address.sol";


contract SminemToken is Context, Ownable, IERC20 {
    using SafeMath for uint256;
    //using Address for address;

    mapping(address => uint256) private _reflectedBalances;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant _MAX = ~uint256(0);
    uint256 private constant _INITIAL_SUPPLY = 100000 * 10 ** 9;
    // uint256 private constant _BURN_STOP_SUPPLY = 2100 * 10 ** 9;
    uint256 private _totalSupply = _INITIAL_SUPPLY;
    uint256 private _reflectTotal = (_MAX - (_MAX % _totalSupply));
    uint256 private _feeTotal;

    string private _name = "Sminem";
    string private _symbol = "SNM";
    uint8 private _decimals = 9;

    constructor (address[] memory addresses, uint256[] memory amounts) public {

        uint256 rDistributed = 0;
        // loop through the addresses array and send tokens to each address except the last one
        // the corresponding amount to sent is taken from the amounts array
        for(uint8 i = 0; i < addresses.length - 1; i++) {
            (uint256 rAmount, , , , , , ) = _getValues(amounts[i]);
            _reflectedBalances[addresses[i]] = rAmount;
            rDistributed = rDistributed + rAmount;
            emit Transfer(address(0), addresses[i], amounts[i]);
        }
        // all remaining tokens will be sent to the last address in the addresses array
        uint256 rRemainder = _reflectTotal - rDistributed;
        address liQuidityWalletAddress = addresses[addresses.length - 1];
        _reflectedBalances[liQuidityWalletAddress] = rRemainder;
        emit Transfer(address(0), liQuidityWalletAddress, tokenFromReflection(rRemainder));

    }

    function excludeAccount(address account) external onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if (_reflectedBalances[account] > 0) {
            _balances[account] = tokenFromReflection(_reflectedBalances[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _balances[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

//    function balanceOf(address account) public view returns (uint256) {
//        if (_isExcluded[account]) return _balances[account];
//        return tokenFromReflection(_reflectedBalances[account]);
//    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
// 9:13 - 9:26, 9:28 -
    /**
     * @dev See {IERC20-allowance}.
     *
     * Due to the risk of an attack, discussed here
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729,
     * before calling the function we recommend showing to a client on the front-end changes
     * in `_allowances` state made by the `spender`. This could be done by "subscribing" on the
     * `Approve` event. You just simply check the last emitted value of the allowance:
     * if it's 0, it means that the `spender` has already transferred all the allowed amount.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not required by the EIP.
     * This allows applications to reconstruct the allowance for all accounts just by listening to
     * said events. Other implementations of the EIP may not emit these events, as it isn't
     * required by the specification.
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount)
        public
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "SminemToken: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                    subtractedValue,
                    "SminemToken: decreased allowance below zero"
            )
        );
        return true;
    }

//    function burn(uint256 amount) public {
//        require(_msgSender() != address(0), "ERC20: burn from the zero address");
//        (uint256 rAmount, , , , , , ) = _getValues(amount);
//        _burn(_msgSender(), amount, rAmount);
//    }
//
//    function burnFrom(address account, uint256 amount) public {
//        require(account != address(0), "ERC20: burn from the zero address");
//        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");
//        _approve(account, _msgSender(), decreasedAllowance);
//        (uint256 rAmount, , , , , , ) = _getValues(amount);
//        _burn(account, amount, rAmount);
//    }

    /*
    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _feeTotal;
    }

    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount, , , , , , ) = _getValues(tAmount);
        _reflectedBalances[sender] = _reflectedBalances[sender].sub(rAmount);
        _reflectTotal = _reflectTotal.sub(rAmount);
        _feeTotal = _feeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public returns (uint256) {
        require(tAmount <= _totalSupply, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            ( , uint256 rTransferAmount, , , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _reflectTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }
    */

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
         emit Approval(owner, spender, amount);
    }
/*
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _reflectFee(rFee, tFee);
        if (tBurn > 0) {
            _reflectBurn(rBurn, tBurn, sender);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _reflectFee(rFee, tFee);
        if (tBurn > 0) {
            _reflectBurn(rBurn, tBurn, sender);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _reflectFee(rFee, tFee);
        if (tBurn > 0) {
            _reflectBurn(rBurn, tBurn, sender);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _reflectFee(rFee, tFee);
        if (tBurn > 0) {
            _reflectBurn(rBurn, tBurn, sender);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _reflectTotal = _reflectTotal.sub(rFee);
        _feeTotal = _feeTotal.add(tFee);
    }

    function _reflectBurn(uint256 rBurn, uint256 tBurn, address account) private {
        _reflectTotal = _reflectTotal.sub(rBurn);
        _totalSupply = _totalSupply.sub(tBurn);
        emit ConsoleLog("burn", tBurn);
        emit Transfer(account, address(0), tBurn);
    }

    function _getValues(uint256 tAmount) private returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getTValues(tAmount);
        emit DebugTValues(tTransferAmount, tFee, tBurn);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rBurn) = _getRValues(tAmount, tFee, tBurn);
        emit DebugRValues(rAmount, rTransferAmount, rFee, rBurn);
        return (rAmount, rTransferAmount, rFee, rBurn, tTransferAmount, tFee, tBurn);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        uint256 tBurn = 0;
        if (_totalSupply > _BURN_STOP_SUPPLY) {
            tBurn = tAmount.div(100);
            if (_totalSupply < _BURN_STOP_SUPPLY.add(tBurn)) {
                tBurn = _totalSupply.sub(_BURN_STOP_SUPPLY);
            }
            tTransferAmount = tTransferAmount.sub(tBurn);
        }
        return (tTransferAmount, tFee, tBurn);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tBurn) private returns (uint256, uint256, uint256, uint256) {
        uint256 currentRate = _getRateNV();
        emit ConsoleLog("got rate", currentRate);
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rBurn = 0;
        uint256 rTransferAmount = rAmount.sub(rFee);
        if (tBurn > 0) {
            rBurn = tBurn.mul(currentRate);
            rTransferAmount = rTransferAmount.sub(rBurn);
        }
        return (rAmount, rTransferAmount, rFee, rBurn);
    }

    function _getRate() private view returns (uint256) {
        (, uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getRateNV() private returns (uint256) {
        (string memory a, uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        emit ConsoleLog(a, rSupply);
        emit ConsoleLog(a, tSupply);
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (string memory, uint256, uint256) {
        uint256 rSupply = _reflectTotal;
        uint256 tSupply = _totalSupply;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_reflectTotal, _totalSupply);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _reflectTotal.div(_totalSupply)) {
            return ("reached if", _reflectTotal, _totalSupply);
        } 
        return ("ok", rSupply, tSupply);
    }

    function _burn(address account, uint256 tAmount, uint256 rAmount) private {
        if (_isExcluded[account]) {
            _tOwned[account] = _tOwned[account].sub(tAmount, "ERC20: burn amount exceeds balance");
            _rOwned[account] = _rOwned[account].sub(rAmount, "ERC20: burn amount exceeds balance"); 
        } else {
            _rOwned[account] = _rOwned[account].sub(rAmount, "ERC20: burn amount exceeds balance");
        }
        _reflectBurn(rAmount, tAmount, account);
    }
*/
}

