// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SurveyRewardSystem {
    IERC20 public token;

    struct Survey {
        string surveyCid;  // IPFS CID of the survey
        uint256 individualReward;
        uint256 expectedRespondents;
        uint256 actualRespondents;
        address creator;
        string encryptionKey;  // an encryption key for encrypting responses
        bool exists;
        mapping(bytes32 => string) encryptedAnswers;  // Hash of respondent address to encrypted answer CID
    }

    mapping(string => Survey) public surveys;

    event SurveyCreated(string surveyCid, uint256 rewardPool, uint256 expectedRespondents, string encryptionKey, address creator);
    event SurveyAnswered(string surveyCid, bytes32 respondentHash, string answerCid);
    event SurveyCancelled(string surveyCid);

    constructor(IERC20 _token) {
        token = _token;
    }

    function createSurvey(string memory surveyCid, uint256 individualReward, uint256 expectedRespondents, string memory encryptionKey) public {
        require(!surveys[surveyCid].exists, "Survey already exists.");
        
        Survey storage survey = surveys[surveyCid];
        survey.surveyCid = surveyCid;
        survey.individualReward = individualReward;
        survey.expectedRespondents = expectedRespondents;
        survey.actualRespondents = 0;
        survey.creator = msg.sender;
        survey.encryptionKey = encryptionKey;
        survey.exists = true;

        uint256 rewardPool = individualReward * expectedRespondents;
        require(token.transferFrom(msg.sender, address(this), rewardPool), "Failed to lock survey rewards.");
        emit SurveyCreated(surveyCid, rewardPool, expectedRespondents, encryptionKey, msg.sender);
    }

    function answerSurvey(string memory surveyCid, string memory encryptedAnswerCid) public {
        require(surveys[surveyCid].exists, "Survey does not exist.");
        bytes32 respondentHash = keccak256(abi.encodePacked(msg.sender));
        require(bytes(surveys[surveyCid].encryptedAnswers[respondentHash]).length == 0, "Responder has already answered this survey.");

        Survey storage survey = surveys[surveyCid];
        require(survey.actualRespondents < survey.expectedRespondents, "Survey has already reached its expected respondents.");

        survey.encryptedAnswers[respondentHash] = encryptedAnswerCid;
        survey.actualRespondents++;
        uint256 rewardAmount = survey.individualReward;
        require(token.transfer(msg.sender, rewardAmount), "Failed to distribute reward.");

        emit SurveyAnswered(surveyCid, respondentHash, encryptedAnswerCid);
    }

    function cancelSurvey(string memory surveyCid) public {
        require(surveys[surveyCid].exists, "Survey does not exist.");
        Survey storage survey = surveys[surveyCid];
        require(msg.sender == survey.creator, "Only the survey creator can cancel the survey.");

        uint256 remainingRewards = survey.individualReward * (survey.expectedRespondents - survey.actualRespondents);
        survey.exists = false;
        require(token.transfer(survey.creator, remainingRewards), "Failed to return remaining rewards.");
        emit SurveyCancelled(surveyCid);
    }
}
