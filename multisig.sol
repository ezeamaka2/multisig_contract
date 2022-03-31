// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract MultiSigWallet{
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);
    
    struct Transaction{
        address to;
        uint256 value;
        bytes data;
        uint256 totalCon;
        bool executed;
    }

    Transaction[] public transactions;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner{
        require(isOwner[msg.sender], "not an owner");
        _;
    }

    modifier txExist(uint256 _txId){
        require(_txId < transactions.length, "This transaction Id does not exit");
        _;
    }

    modifier notApproved(uint256 _txId){
        require(!approved[_txId][msg.sender],"This transaction has already been approved");
        _;
    }

    modifier notExecuted(uint256 _txId){
        require(transactions[_txId].executed == false, "This transaction has been executed!");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "owners is required");
        require(_required > 0 && _required <= _owners.length, "invalid required number");

        for(uint i; i < _owners.length; i++){
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner],"");

            // if its is unique, add it to the isOwner mapping and push to the owners array
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    // Send ether to the smart contract
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
        ) external onlyOwner {
            transactions.push(Transaction(_to, _value, _data, 0, false));
            emit Submit(transactions.length - 1);
        }

    function approve(uint256 _txId) external onlyOwner txExist(_txId) notApproved(_txId) notExecuted(_txId){
        approved[_txId][msg.sender] = true;
        transactions[_txId].totalCon += 1;

        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txId) internal view returns(uint256 count){
        for(uint256 i; i < owners.length; i++){
            if(approved[_txId][msg.sender]){
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExist(_txId) notExecuted(_txId){
        Transaction storage transaction = transactions[_txId];
        require(transaction.totalCon >= required, "approval < required");

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "Transaction failed");

        emit Execute(_txId);
    }

    function revoke(uint256 _txId) external onlyOwner txExist(_txId) notExecuted(_txId){
        Transaction storage transaction = transactions[_txId];
        require(approved[_txId][msg.sender] = true, "You have not approved this tx");
        approved[_txId][msg.sender] = false;
        transaction.executed = false;

        emit Revoke(msg.sender, _txId);
    }
    
}