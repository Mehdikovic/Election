/**
* Simple Election
* @author Mehdikovic
* Date created: 2022.04.05
* Github: mehdikovic
* SPDX-License-Identifier: MIT
*/


pragma solidity ^0.8.4;

import "hardhat/console.sol";

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {WakandaToken} from "./WakandaToken.sol";

struct Candidate {
    uint256 id;
    string name;
    string cult;
    uint8 age;
    uint64 votes; // TODO may need smaller size
}

library Sort {
    function quickSort(Candidate[] storage data) internal {
        uint256 n = data.length;
        Candidate[] memory arr = new Candidate[](n);
        uint256 i;

        for(i = 0; i < n; i++) {
            arr[i] = data[i]; // cloning
        }

        uint256[] memory stack = new uint256[](n + 2);

        //Push initial lower and higher bound
        uint256 top = 1;
        stack[top] = 0;
        top++;
        stack[top] = n - 1;

        //Keep popping from stack while is not empty
        while (top > 0) {
            uint256 high = stack[top];
            top--;
            uint256 low = stack[top];
            top--;

            i = low;
            Candidate memory x = arr[high];

            for(uint256 j = low; j < high; j++) {
                if (arr[j].votes > x.votes) {
                    (arr[i], arr[j]) = (arr[j], arr[i]);
                    i = i + 1;
                }
            }
            (arr[i], arr[high]) = (arr[high], arr[i]);
            uint256 p = i;

            //Push left side to stack
            if (p > low + 1) {
                top = top + 1;
                stack[top] = low;
                top = top + 1;
                stack[top] = p - 1;
            }

            //Push right side to stack
            if (p + 1 < high) {
                top = top + 1;
                stack[top] = p + 1;
                top = top + 1;
                stack[top] = high;
            }
        }

        for(i = 0; i < n; i++) {
            data[i] = arr[i]; // filling our data storage with the sorted array
        }
    }
}

contract Election is Ownable {
    using Sort for Candidate[];
    uint256 constant public MAX_UINT = type(uint256).max;
    
    uint256 public topCandidatesCount = 3;

    WakandaToken public wakanda;

    Candidate[] public sortedCandidates;
    mapping(uint256 => Candidate) public id2candidates; // candidate's id => Candidate; O(1)
    
    mapping(address => mapping(uint256 => bool)) public userCastedVote; // voter's address => candidate's id => is she/he voted or not?
    mapping(uint256 => address[]) internal candidate2Voters; // returns the list of addresses who have voted to this particular candidate
    mapping(address => uint256[]) internal voter2Candidates; // returns the list of candidates who user has voted to

    event CandidateAdded(uint256 indexed id);
    event NewChallenger(uint256 indexed candidateId, uint256 slot);
    event VoteCasted(address indexed voter, uint256 indexed candidateId, uint256 newVotedCount);

    constructor(address _wakandaToken) {
        require(_wakandaToken != address(0), "address is Zero");
        wakanda = WakandaToken(_wakandaToken);
    }

    function registerCandidate(string memory _name, string memory _cult, uint8 _age) external onlyOwner {
        require(bytes(_name).length > 0, "invalid name");
        require(bytes(_cult).length > 0, "invalid culture");
        require(_age > 18, "invalid age");
        
        // we don't have a candidate with 0 id, you can change it if you like
        uint256 id = sortedCandidates.length + 1;
        Candidate memory newCandidate = Candidate(id, _name, _cult, _age, 0);
        id2candidates[id] = newCandidate;
        sortedCandidates.push(newCandidate);

        emit CandidateAdded(id);
        // no need to sort them, because they have been added with zero votes to the end of the list
    }

    function castVote(uint256 _id) external onlyValidCandidate(_id) {
        require(wakanda.isRegistered(msg.sender) == true, "has not been registered yet");
        require(userCastedVote[msg.sender][_id] == false, "voted before");
        
        userCastedVote[msg.sender][_id] = true; // acts exactly as a reentrancy guard
        uint256 len = sortedCandidates.length;
        candidate2Voters[_id].push(msg.sender);
        voter2Candidates[msg.sender].push(_id);

        // I think we should send one token here
        uint256 amount = 1 ether;
        require(wakanda.balanceOf(_msgSender()) >= amount, "not enough balance");
        require(wakanda.approve(address(this), amount), "not enough balance");

        wakanda.transferFrom(_msgSender(), address(this), amount);

        id2candidates[_id].votes++;
        for (uint256 i = 0; i < len; i++) {
            if (sortedCandidates[i].id == _id) {
                sortedCandidates[i].votes++;
                break;
            }
        }

        uint256 beforeSortIndex = MAX_UINT;
        
        for (uint256 i = 0; i < topCandidatesCount; i++) {
            if (i < len && sortedCandidates[i].id == _id) {
                beforeSortIndex = i;
                break;
            }
        }

        sortedCandidates.quickSort();
        //Sort.quickSort(sortedCandidates);

        uint256 afterSortIndex = MAX_UINT;

        for (uint256 i = 0; i < topCandidatesCount; i++) {
            if (i < len && sortedCandidates[i].id == _id) {
                afterSortIndex = i;
                break;
            }
        }

        if (afterSortIndex != MAX_UINT) { // new candidate is part of top 3 candidates
            /*
            // item was part of top candidates before sort, and is part of top again
            if (beforeSortIndex != MAX_UINT && afterSortIndex < beforeSortIndex) {
                emit NewChallenger();
            }
            */

            // special case for the first top candidates receiving their first vote
            if (afterSortIndex == beforeSortIndex
                && sortedCandidates[afterSortIndex].votes == 1) {
                emit NewChallenger(_id, afterSortIndex);
            }

            // candidate has moved up to top three
            //if (beforeSortIndex == MAX_UINT && afterSortIndex < beforeSortIndex) {
            //    emit NewChallenger(_id, afterSortIndex);
            //}

            if (afterSortIndex < beforeSortIndex) {
                emit NewChallenger(_id, afterSortIndex);
            }
        }

        emit VoteCasted(msg.sender, _id, id2candidates[_id].votes);
    }

    /* VIEW */

    function getSortedCandidates() external view returns (Candidate[] memory) {
        return sortedCandidates;
    }

    function getVotersOfCandidate(uint256 _id) external onlyValidCandidate(_id) view returns (address[] memory) {
        return candidate2Voters[_id];
    }

    function getCandidatesOfVoter(address voter) external view returns (uint256[] memory) {
        return voter2Candidates[voter];
    }

    modifier onlyValidCandidate(uint256 _id) {
        require(_id > 0 && _id <= sortedCandidates.length, "candidate is not registered");
        _;
    }
}