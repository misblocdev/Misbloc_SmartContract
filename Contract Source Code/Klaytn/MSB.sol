pragma solidity 0.5.17;

library SafeMath
{
    function add(uint256 a, uint256 b) internal pure returns(uint256 c)
    {
        c = a + b;
        require(c >= a, "SafeMath: addition overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns(uint256 c)
    {
        require(b <= a, "SafeMath: subtraction overflow");
        c = a - b;
    }
}

library Address
{
    function isContract(address account) internal view returns(bool)
    {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly { codehash:= extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
}

interface IKIP7Receiver
{
    function onKIP7Received(address _operator, address _from, uint256 _amount, bytes calldata _data) external returns(bytes4);
}

contract Variable
{
    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;
    address public owner;

    uint256 internal _decimals;
    bool internal transferLock;

    mapping(address => bool) public allowedAddress;
    mapping(address => bool) public blockedAddress;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) internal allowed;

    mapping(bytes4 => bool) internal _supportedInterfaces;
    bytes4 private constant _INTERFACE_ID_KIP13 = 0x01ffc9a7;
    bytes4 private constant _INTERFACE_ID_KIP7 = 0x65787371;
    bytes4 private constant _INTERFACE_ID_KIP7_METADATA = 0xa219a025;
    bytes4 private constant _INTERFACE_ID_KIP7BURNABLE = 0x3b5a0bf8;

    function _registerInterface(bytes4 interfaceId) internal
    {
        require(interfaceId != 0xffffffff, "KIP13: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }

    constructor() public
    {
        name = "MISBLOC";
        symbol = "MSB";
        decimals = 18;
        _decimals = 10 ** uint256(decimals);
        totalSupply = _decimals * 300000000;
        transferLock = false;
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
        allowedAddress[owner] = true;

        _registerInterface(_INTERFACE_ID_KIP13);
        _registerInterface(_INTERFACE_ID_KIP7);
        _registerInterface(_INTERFACE_ID_KIP7_METADATA);
        _registerInterface(_INTERFACE_ID_KIP7BURNABLE);
    }
}
contract Modifiers is Variable
{
    modifier isOwner
    {
        assert(owner == msg.sender);
        _;
    }
}
contract Event
{
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokenBurn(address indexed from, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract Admin is Variable, Modifiers, Event
{
    using SafeMath for uint256;

    function tokenBurn(uint256 _value) public isOwner returns(bool success)
    {
        require(balanceOf[msg.sender] >= _value, "Invalid balance");
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit TokenBurn(msg.sender, _value);
        return true;
    }
    function addAllowedAddress(address _address) public isOwner
    {
        allowedAddress[_address] = true;
    }
    function deleteAllowedAddress(address _address) public isOwner
    {
        require(_address != owner, "only allow user address");
        allowedAddress[_address] = false;
    }
    function addBlockedAddress(address _address) public isOwner
    {
        require(_address != owner, "only allow user address");
        blockedAddress[_address] = true;
    }
    function deleteBlockedAddress(address _address) public isOwner
    {
        blockedAddress[_address] = false;
    }
    function setTransferLock(bool _transferLock) public isOwner returns(bool success)
    {
        transferLock = _transferLock;
        return true;
    }
}
contract MSB is Variable, Event, Admin
{
    using Address for address;
    bytes4 private _KIP7_RECEIVED = 0x9d188c22;

    function() external payable
    {
        revert();
    }
    function supportsInterface(bytes4 interfaceId) external view returns(bool) {
        return _supportedInterfaces[interfaceId];
    }
    function get_transferLock() public view returns(bool)
    {
        return transferLock;
    }
    function allowance(address tokenOwner, address spender) public view returns(uint256 remaining)
    {
        return allowed[tokenOwner][spender];
    }
    function increaseApproval(address _spender, uint256 _addedValue) public returns(bool)
    {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    function decreaseApproval(address _spender, uint256 _subtractedValue) public returns(bool)
    {
        uint256 oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        }
        else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    function approve(address _spender, uint256 _value) public returns(bool)
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    function safeTransferFrom(address _from, address _to, uint256 _value) public
    {
        safeTransferFrom(_from, _to, _value, "");
    }
    function safeTransferFrom(address _from, address _to, uint256 _value, bytes memory data) public
    {
        transferFrom(_from, _to, _value);
        require(_checkOnKIP7Received(_from, _to, _value, data), "KIP7: transfer to non KIP7Receiver implementer");
    }
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool)
    {
        require(allowedAddress[_from] || transferLock == false, "Transfer lock : true");
        require(!blockedAddress[_from] && !blockedAddress[_to] && !blockedAddress[msg.sender], "Blocked address");
        require(balanceOf[_from] >= _value && (balanceOf[_to].add(_value)) >= balanceOf[_to], "Invalid balance");
        require(_value <= allowed[_from][msg.sender], "Invalid balance : allowed");

        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    function safeTransfer(address _to, uint256 _value) public returns(bool)
    {
        safeTransfer(_to, _value, "");
        return true;
    }
    function safeTransfer(address _to, uint256 _value, bytes memory data) public returns(bool)
    {
        transfer(_to, _value);
        require(_checkOnKIP7Received(msg.sender, _to, _value, data), "KIP7: transfer to non KIP7Receiver implementer");
        return true;
    }
    function transfer(address _to, uint256 _value) public returns(bool)
    {
        require(allowedAddress[msg.sender] || transferLock == false, "Transfer lock : true");
        require(!blockedAddress[msg.sender] && !blockedAddress[_to], "Blocked address");
        require(balanceOf[msg.sender] >= _value && (balanceOf[_to].add(_value)) >= balanceOf[_to], "Invalid balance");

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function _checkOnKIP7Received(address sender, address recipient, uint256 amount, bytes memory _data) internal returns(bool)
    {
        if (!recipient.isContract())
        {
            return true;
        }
        bytes4 retval = IKIP7Receiver(recipient).onKIP7Received(msg.sender, sender, amount, _data);
        return (retval == _KIP7_RECEIVED);
    }
}
