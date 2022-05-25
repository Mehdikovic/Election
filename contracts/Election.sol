/**
* Simple Election
* @author Mehdikovic
* Date created: 2022.04.05
* Github: mehdikovic
* SPDX-License-Identifier: MIT
*/


pragma solidity ^0.8.4;

import "hardhat/console.sol";

struct Candidate {
    uint256 index;
    uint256 id;
    string name;
    string cult;
    uint8 age;
    uint64 votes; // TODO may need smaller size
}

uint256 constant MAX_UINT = type(uint256).max;

library Sort {

    function quickSort(Candidate[] storage data, mapping(uint256 => Candidate) storage id2Candidate) internal {
        uint256 n = data.length;
        Candidate[] memory arr = new Candidate[](n);
        uint256 i;

        for(i = 0; i < n; i++) {
            arr[i] = data[i];
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
            if (id2Candidate[arr[i].id].index != i) {
                id2Candidate[arr[i].id].index = i;
            }
            data[i] = arr[i];
        }
    }
}

// TODO add onlyMember modifier to protect smart contract

contract Election {
    using Sort for Candidate[];

    mapping(uint256 => Candidate) public id2candidate;
    mapping(address => mapping(uint256 => bool)) public userCastedVote; // user's address => candidate's id => true/false
    mapping(uint256 => address[]) internal candidate2Voters;
    mapping(address => uint256[]) internal voter2Candidates;
    Candidate[] public sortedCandidates;
    uint256 public topCandidatesCount = 3;

    event CandidateAdded(uint256 indexed id);
    event NewChallenger(uint256 indexed candidateId, uint256 slot);
    event VoteCasted(address indexed voter, uint256 indexed candidateId, uint256 newVotedCount);

    function registerCandidate(string memory _name, string memory _cult, uint8 _age) external {
        require(bytes(_name).length > 0, "invalid name");
        require(bytes(_cult).length > 0, "invalid culture");
        require(_age > 18, "invalid age"); // TODO add a valid age limit
        
        uint256 id = sortedCandidates.length + 1; // we don't have a candidate with 0 id, you can change it if you like
        Candidate memory newCandidate = Candidate(id - 1, id, _name, _cult, _age, 0);
        id2candidate[id] = newCandidate;
        sortedCandidates.push(newCandidate);

        emit CandidateAdded(id);
        // no need to sort them, because they have been added with zero votes
    }

    function castVote(uint256 _id) external onlyValidCandidate(_id) {
        // TODO check for the token requirements
        require(userCastedVote[msg.sender][_id] == false, "voted before");
        
        uint256 len = sortedCandidates.length;
        userCastedVote[msg.sender][_id] = true;
        candidate2Voters[_id].push(msg.sender);
        voter2Candidates[msg.sender].push(_id);

        // I think we should send one token here

        id2candidate[_id].votes++;
        sortedCandidates[id2candidate[_id].index].votes++;

        uint256 beforeSortIndex = MAX_UINT;

        for (uint256 i = 0; i < topCandidatesCount; i++) {
            if (i < len && sortedCandidates[i].id == _id) {
                beforeSortIndex = i;
                break;
            }
        }

        sortedCandidates.quickSort(id2candidate);

        uint256 afterSortIndex = MAX_UINT;

        for (uint256 i = 0; i < topCandidatesCount; i++) {
            if (i < len && sortedCandidates[i].id == _id) {
                afterSortIndex = i;
                break;
            }
        }

        if (afterSortIndex != MAX_UINT) { // new candidate is part of top candidates
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
            if (afterSortIndex < beforeSortIndex) {
                emit NewChallenger(_id, afterSortIndex);
            }
        }

        emit VoteCasted(msg.sender, _id, id2candidate[_id].votes);
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